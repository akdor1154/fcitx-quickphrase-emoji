-- Load emoji from the system's Unicode files.
--
-- emoji-test.txt (Debian/Ubuntu package unicode-data) gives the fully-qualified
-- sequence to commit, the official name and a sensible order. CLDR annotations
-- (package unicode-cldr-core) give localised names and search keywords. CLDR
-- strips U+FE0F, so the two are joined on the FE0F-free form.

local M = {}

M.DEFAULT_EMOJI_TEST = "/usr/share/unicode/emoji/emoji-test.txt"
M.DEFAULT_CLDR_DIR = "/usr/share/unicode/cldr/common"

local FE0F = utf8.char(0xFE0F)

local function read_file(path)
    local f, err = io.open(path, "rb")
    if not f then
        return nil, err
    end
    local content = f:read("a")
    f:close()
    return content
end

function M.strip_fe0f(s)
    return (s:gsub(FE0F, ""))
end

local function is_skin_tone(cp)
    return cp >= 0x1F3FB and cp <= 0x1F3FF
end

local function has_skin_tone(s)
    for _, cp in utf8.codes(s) do
        if is_skin_tone(cp) then
            return true
        end
    end
    return false
end

--- Parse emoji-test.txt content.
-- Keeps fully-qualified emoji only, and drops the Component group and
-- skin-tone variants.
-- @treturn table array of {emoji, key, name, group, subgroup, version}
function M.parse_emoji_test(content)
    local entries = {}
    local group, subgroup = "", ""
    for line in content:gmatch("[^\n]+") do
        local g = line:match("^# group: (.-)%s*$")
        local sg = line:match("^# subgroup: (.-)%s*$")
        if g then
            group = g
        elseif sg then
            subgroup = sg
        elseif line:sub(1, 1) ~= "#" then
            local cps, status, version, name =
                line:match("^([%x ]+);%s*([%a-]+)%s*#%s*%S+%s+E([%d.]+)%s+(.-)%s*$")
            if cps and status == "fully-qualified" and group ~= "Component" then
                local chars, skin = {}, false
                for hex in cps:gmatch("%x+") do
                    local cp = tonumber(hex, 16)
                    skin = skin or is_skin_tone(cp)
                    chars[#chars + 1] = utf8.char(cp)
                end
                if not skin then
                    local emoji = table.concat(chars)
                    entries[#entries + 1] = {
                        emoji = emoji,
                        key = M.strip_fe0f(emoji),
                        name = name,
                        group = group,
                        subgroup = subgroup,
                        version = version,
                    }
                end
            end
        end
    end
    return entries
end

local ENTITIES = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }

local function decode_entities(s)
    return (s:gsub("&(#?x?)(%w+);", function(prefix, body)
        if prefix == "" then
            return ENTITIES[body]
        end
        local n = tonumber(body, prefix == "#x" and 16 or 10)
        return n and utf8.char(n)
    end))
end

local function split_keywords(s)
    local out = {}
    for item in (s .. "|"):gmatch("(.-)|") do
        item = item:match("^%s*(.-)%s*$")
        if item ~= "" then
            out[#out + 1] = item
        end
    end
    return out
end

-- CLDR uses this value to mean "inherit from the parent locale".
local INHERIT = "↑↑↑"

local function add_keyword(item, kw)
    if not item.seen[kw] then
        item.seen[kw] = true
        item.keywords[#item.keywords + 1] = kw
    end
end

--- Parse one CLDR annotations XML file into `into`.
-- CLDR's own rule is that a child locale replaces its parent's value. That is
-- right for the display name, but for search it throws away useful words
-- (en_001 replaces en's "tada" with "ta-da"), so keywords accumulate across
-- files and a replaced name is kept as a keyword.
-- @tparam string content file content
-- @tparam table into map of FE0F-free sequence -> {name=, keywords=, seen=}
function M.parse_cldr(content, into)
    into = into or {}
    for cp, attrs, text in content:gmatch('<annotation cp="([^"]*)"([^>]*)>([^<]*)</annotation>') do
        text = decode_entities(text)
        if text ~= INHERIT then
            local key = M.strip_fe0f(decode_entities(cp))
            local item = into[key]
            if not item then
                item = { keywords = {}, seen = {} }
                into[key] = item
            end
            if attrs:find('type="tts"', 1, true) then
                if item.name and item.name ~= text then
                    add_keyword(item, item.name)
                end
                item.name = text
            else
                for _, kw in ipairs(split_keywords(text)) do
                    add_keyword(item, kw)
                end
            end
        end
    end
    return into
end

--- Work out the CLDR locale chain for a POSIX locale string.
-- "en_AU.UTF-8" gives {"en", "en_001", "en_AU"}; parents come first so that
-- children override them.
function M.locale_chain(locale)
    locale = (locale or ""):gsub("[.@].*$", ""):gsub("-", "_")
    local lang, rest = locale:match("^(%a%a%a?)_?(.*)$")
    if not lang or locale == "C" or locale == "POSIX" then
        return { "en" }
    end
    lang = lang:lower()
    local chain = { lang }
    if rest ~= "" then
        if lang == "en" and rest ~= "US" then
            chain[#chain + 1] = "en_001"
        end
        chain[#chain + 1] = lang .. "_" .. rest
    end
    return chain
end

--- Load CLDR annotations for a locale chain from a CLDR "common" directory.
-- Missing files are skipped.
-- @treturn table map of FE0F-free sequence -> {name=, keywords=}
-- @treturn table list of files read
function M.load_cldr(cldr_dir, chain)
    local into, used = {}, {}
    for _, loc in ipairs(chain) do
        for _, sub in ipairs({ "annotations", "annotationsDerived" }) do
            local path = cldr_dir .. "/" .. sub .. "/" .. loc .. ".xml"
            local content = read_file(path)
            if content then
                M.parse_cldr(content, into)
                used[#used + 1] = path
            end
        end
    end
    return into, used
end

local function first_codepoint(s)
    local ok, cp = pcall(utf8.codepoint, s, 1)
    return ok and cp or nil
end

--- ISO 3166 code of a country flag ("au" for 🇦🇺), or nil.
-- A flag is two regional indicator symbols, U+1F1E6 (A) to U+1F1FF (Z).
function M.flag_code(s)
    local letters = {}
    for _, cp in utf8.codes(s) do
        if cp < 0x1F1E6 or cp > 0x1F1FF or #letters == 2 then
            return nil
        end
        letters[#letters + 1] = string.char(cp - 0x1F1E6 + 97)
    end
    return #letters == 2 and table.concat(letters) or nil
end

local function with_flag_code(emoji, keywords)
    local code = M.flag_code(emoji)
    if not code then
        return keywords
    end
    local out = { code }
    for _, kw in ipairs(keywords) do
        out[#out + 1] = kw
    end
    return out
end

--- Build the final emoji list.
-- Every emoji-test entry is kept, with CLDR's name and keywords where CLDR has
-- them. CLDR-only emoji (newer than emoji-test.txt) are appended if they look
-- like pictographic emoji rather than the plain symbols CLDR also annotates.
-- @treturn table array of {emoji, name, alt_name, keywords, group, order}
function M.merge(test_entries, cldr)
    local out, seen = {}, {}
    for _, e in ipairs(test_entries) do
        local c = cldr[e.key] or {}
        local name = c.name or e.name
        out[#out + 1] = {
            emoji = e.emoji,
            name = name,
            alt_name = (name ~= e.name) and e.name or nil,
            keywords = with_flag_code(e.emoji, c.keywords or {}),
            group = e.group,
            order = #out + 1,
        }
        seen[e.key] = true
    end
    local extra = {}
    for key, c in pairs(cldr) do
        if not seen[key] and c.name then
            local cp = first_codepoint(key)
            if cp and cp >= 0x1F000 and not has_skin_tone(key) then
                extra[#extra + 1] = key
            end
        end
    end
    table.sort(extra)
    for _, key in ipairs(extra) do
        local c = cldr[key]
        out[#out + 1] = {
            emoji = key,
            name = c.name,
            keywords = c.keywords or {},
            group = "",
            order = #out + 1,
        }
    end
    return out
end

--- Load and merge everything.
-- @tparam table opts {emoji_test=path, cldr_dir=path, locale=string}
-- @treturn table|nil emoji list, or nil and an error message
-- @treturn table info {sources = {...}, cldr_only = n}
function M.load(opts)
    opts = opts or {}
    local test_path = opts.emoji_test or M.DEFAULT_EMOJI_TEST
    local cldr_dir = opts.cldr_dir or M.DEFAULT_CLDR_DIR
    local content, err = read_file(test_path)
    if not content then
        return nil, "cannot read " .. test_path .. ": " .. tostring(err)
            .. " (install the unicode-data package)"
    end
    local test_entries = M.parse_emoji_test(content)
    if #test_entries == 0 then
        return nil, "no emoji found in " .. test_path
    end
    local chain = M.locale_chain(opts.locale)
    local cldr, used = M.load_cldr(cldr_dir, chain)
    local sources = { test_path }
    for _, p in ipairs(used) do
        sources[#sources + 1] = p
    end
    local merged = M.merge(test_entries, cldr)
    return merged, { sources = sources, cldr_only = #merged - #test_entries }
end

return M
