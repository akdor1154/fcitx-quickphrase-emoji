-- Parse fcitx key strings ("Super+period") and match them against the
-- (sym, state) pairs a Lua key watcher receives.
--
-- fcitx hands key watchers a normalised key (fcitx::Key::normalize()), so a
-- configured key has to go through the same normalisation before comparing.

local M = {}

local STATE = {
    Shift = 1 << 0,
    CapsLock = 1 << 1,
    Ctrl = 1 << 2,
    Alt = 1 << 3,
    NumLock = 1 << 4,
    Mod3 = 1 << 5,
    Super = 1 << 6,
    Super2 = 1 << 26,
}
M.STATE = STATE

-- Modifier names accepted in key strings. fcitx's normalisation drops Hyper
-- and Meta, so a key using them could never match and is rejected.
local MODIFIERS = {
    control = STATE.Ctrl,
    ctrl = STATE.Ctrl,
    alt = STATE.Alt,
    shift = STATE.Shift,
    super = STATE.Super,
}

local NAMED = {
    space = 0x20, exclam = 0x21, quotedbl = 0x22, numbersign = 0x23,
    dollar = 0x24, percent = 0x25, ampersand = 0x26, apostrophe = 0x27,
    parenleft = 0x28, parenright = 0x29, asterisk = 0x2a, plus = 0x2b,
    comma = 0x2c, minus = 0x2d, period = 0x2e, slash = 0x2f,
    colon = 0x3a, semicolon = 0x3b, less = 0x3c, equal = 0x3d,
    greater = 0x3e, question = 0x3f, at = 0x40,
    bracketleft = 0x5b, backslash = 0x5c, bracketright = 0x5d,
    asciicircum = 0x5e, underscore = 0x5f, grave = 0x60,
    braceleft = 0x7b, bar = 0x7c, braceright = 0x7d, asciitilde = 0x7e,
    BackSpace = 0xff08, Tab = 0xff09, Return = 0xff0d, Escape = 0xff1b,
    Home = 0xff50, Left = 0xff51, Up = 0xff52, Right = 0xff53, Down = 0xff54,
    Page_Up = 0xff55, Page_Down = 0xff56, End = 0xff57, Insert = 0xff63,
    Menu = 0xff67, Delete = 0xffff,
}
for i = 1, 35 do
    NAMED["F" .. i] = 0xffbe + i - 1
end

local KEEP = STATE.Ctrl | STATE.Alt | STATE.Shift | STATE.Super | STATE.Mod3 | STATE.Super2

local function is_lower(sym)
    return sym >= 0x61 and sym <= 0x7a
end

local function is_upper(sym)
    return sym >= 0x41 and sym <= 0x5a
end

-- Printable keysyms: ASCII and Latin-1, which map to their own code point.
local function is_printable(sym)
    return (sym > 0x20 and sym <= 0x7e) or (sym >= 0xa0 and sym <= 0xff)
end

--- Apply fcitx::Key::normalize() to a (sym, state) pair.
function M.normalize(sym, state)
    if sym == 0xfe20 then -- ISO_Left_Tab
        sym = 0xff09
    end
    state = state & KEEP
    if state & STATE.Super2 ~= 0 then
        state = (state & ~STATE.Super2) | STATE.Super
    end
    if state ~= 0 then
        if state ~= STATE.Shift and is_lower(sym) then
            sym = sym - 0x20
        end
        if is_lower(sym) or is_upper(sym) then
            if state == STATE.Shift then
                state = 0
            end
        elseif state & STATE.Shift ~= 0 and is_printable(sym) then
            state = state ~ STATE.Shift
        end
    end
    return sym, state
end

--- Parse a key string such as "Super+period" or "Control+Alt+e".
-- @treturn table|nil {sym=, state=, text=} normalised, or nil and an error
function M.parse(text)
    if type(text) ~= "string" or text == "" then
        return nil, "empty key"
    end
    local parts = {}
    for part in text:gmatch("[^+]+") do
        parts[#parts + 1] = part
    end
    if #parts == 0 or text:sub(-1) == "+" then
        return nil, "malformed key '" .. text .. "' (write '+' as 'plus')"
    end
    local state = 0
    for i = 1, #parts - 1 do
        local bit = MODIFIERS[parts[i]:lower()]
        if not bit then
            return nil, "unknown modifier '" .. parts[i] .. "' in '" .. text .. "'"
        end
        state = state | bit
    end
    local name = parts[#parts]
    local sym
    if NAMED[name] then
        sym = NAMED[name]
    elseif #name == 1 and is_printable(name:byte()) then
        sym = name:byte()
    elseif name:match("^0x%x+$") then
        sym = tonumber(name:sub(3), 16)
    else
        return nil, "unknown key name '" .. name .. "' in '" .. text .. "'"
    end
    sym, state = M.normalize(sym, state)
    return { sym = sym, state = state, text = text }
end

--- True if a key watcher's (sym, state) is the parsed key.
function M.matches(key, sym, state)
    local s, st = M.normalize(sym, state)
    return s == key.sym and st == key.state
end

-- Keysyms for the modifier keys themselves (Shift_L ... Hyper_R, plus the
-- level-shift and lock keys).
function M.is_modifier(sym)
    return (sym >= 0xffe1 and sym <= 0xffee) or sym == 0xfe03 or sym == 0xfe11
        or sym == 0xff7e or sym == 0xff7f
end

return M
