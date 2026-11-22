-- Prefix search over an emoji list.
--
-- Every word of the query must be the start of a word in the emoji's name or
-- keywords, in any order. Results are ranked by how well each query word
-- matched (see RANK), then by shorter name, then by emoji-test.txt order.

local M = {}

-- Per query word. An exact keyword beats a name prefix, so "lit" finds 🔥
-- (keyword "lit") before 🚮 ("litter in bin sign").
local RANK = {
    name_exact = 4,
    keyword_exact = 3,
    name_prefix = 2,
    keyword_prefix = 1,
}

--- Lower-case and split text into words.
-- Apostrophes are dropped so "woman's" and "woman’s" both become "womans";
-- any other punctuation separates words.
function M.words(text)
    text = text:lower():gsub("’", ""):gsub("'", "")
    local out = {}
    for w in text:gmatch("[%w\128-\255]+") do
        out[#out + 1] = w
    end
    return out
end

local function best_match(token, words, exact, prefix)
    local best = 0
    for _, w in ipairs(words) do
        if w == token then
            return exact
        elseif best == 0 and w:sub(1, #token) == token then
            best = prefix
        end
    end
    return best
end

local Index = {}
Index.__index = Index

--- Build a search index.
-- @tparam table list emoji list from data.load: {emoji, name, alt_name, keywords, order}
function M.new(list)
    local self = setmetatable({ entries = {} }, Index)
    for i, item in ipairs(list) do
        local kw = {}
        for _, phrase in ipairs(item.keywords or {}) do
            for _, w in ipairs(M.words(phrase)) do
                kw[#kw + 1] = w
            end
        end
        if item.alt_name then
            for _, w in ipairs(M.words(item.alt_name)) do
                kw[#kw + 1] = w
            end
        end
        self.entries[i] = {
            emoji = item.emoji,
            name = item.name,
            name_words = M.words(item.name),
            keyword_words = kw,
            order = item.order or i,
        }
    end
    return self
end

--- Search for emoji.
-- @tparam string query what the user typed
-- @tparam[opt=50] int limit maximum results
-- @treturn table array of {emoji, name, display}
function Index:search(query, limit)
    limit = limit or 50
    local tokens = M.words(query)
    if #tokens == 0 then
        return {}
    end
    local hits = {}
    for _, e in ipairs(self.entries) do
        local score = 0
        for _, t in ipairs(tokens) do
            local s = math.max(
                best_match(t, e.name_words, RANK.name_exact, RANK.name_prefix),
                best_match(t, e.keyword_words, RANK.keyword_exact, RANK.keyword_prefix))
            if s == 0 then
                score = nil
                break
            end
            score = score + s
        end
        if score then
            hits[#hits + 1] = { entry = e, score = score }
        end
    end
    table.sort(hits, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        if #a.entry.name ~= #b.entry.name then
            return #a.entry.name < #b.entry.name
        end
        return a.entry.order < b.entry.order
    end)
    local out = {}
    for i = 1, math.min(limit, #hits) do
        local e = hits[i].entry
        out[i] = { emoji = e.emoji, name = e.name, display = e.emoji .. " " .. e.name }
    end
    return out
end

return M
