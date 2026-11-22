-- Emoji mode for fcitx5 Quick Phrase.
--
-- How emoji mode is entered: the emoji hotkey must also be one of Quick
-- Phrase's own trigger keys. fcitx runs Lua key watchers in the PreInputMethod
-- phase and Quick Phrase's trigger check in PostInputMethod, so on_key sees the
-- hotkey first, records that emoji mode is wanted, and lets the key through so
-- Quick Phrase opens. While Quick Phrase is open it consumes typed keys before
-- on_key sees them, so the next key that reaches on_key comes after Quick
-- Phrase has closed, and it clears emoji mode.
--
-- This module does not require "fcitx", so it can be tested outside fcitx.

local data = require("emojipicker.data")
local search = require("emojipicker.search")

local M = {}

-- The emoji hotkey, Super+E. fcitx normalises a key before watchers see it,
-- and a letter held with a modifier other than Shift arrives upper case, so
-- this is keysym E (0x45), not e (0x65). To change the key, look up its keysym
-- in /usr/include/xkbcommon/xkbcommon-keysyms.h.
M.HOTKEY_SYM = 0x45
M.HOTKEY_STATE = 1 << 6 -- fcitx.KeyState.Super

-- Keysyms of the modifier keys themselves: Shift_L to Hyper_R, then
-- ISO_Level3_Shift, ISO_Level5_Shift, Mode_switch and Num_Lock.
local function is_modifier(sym)
    return (sym >= 0xffe1 and sym <= 0xffee) or sym == 0xfe03 or sym == 0xfe11
        or sym == 0xff7e or sym == 0xff7f
end

local App = {}
App.__index = App

--- Create the picker and load the emoji data.
-- @tparam table opts
--   actions: fcitx.QuickPhraseAction (required)
--   max_results: default 50
--   locale, emoji_test, cldr_dir: passed to data.load
--   log: function(string) for information, error: function(string) for errors
function M.new(opts)
    local self = setmetatable({
        actions = assert(opts.actions, "opts.actions is required"),
        max_results = opts.max_results or 50,
        log = opts.log or function() end,
        error = opts.error or opts.log or function() end,
        emoji_mode = false,
    }, App)

    local started = os.clock()
    local list, info = data.load({
        locale = opts.locale,
        emoji_test = opts.emoji_test,
        cldr_dir = opts.cldr_dir,
    })
    if not list then
        self.error("emojipicker: " .. info)
        return self
    end
    self.index = search.new(list)
    self.log(("emojipicker: loaded %d emoji in %.0f ms from %s"):format(
        #list, (os.clock() - started) * 1000, table.concat(info.sources, ", ")))
    return self
end

--- Key watcher. Never consumes the key.
-- Releases and modifier keys are ignored: Quick Phrase lets both through
-- while it is open, and they must not clear emoji mode mid-search.
function App:on_key(sym, state, release)
    if release or is_modifier(sym) then
        return false
    end
    self.emoji_mode = sym == M.HOTKEY_SYM and state == M.HOTKEY_STATE
    return false
end

--- Quick Phrase handler.
-- In emoji mode, returns emoji results and stops the built-in tables and spell
-- suggestions. Otherwise returns nothing, so Quick Phrase behaves as normal.
function App:on_quickphrase(input)
    if not self.emoji_mode or not self.index then
        return nil
    end
    local A = self.actions
    local out = { { "", "", A.Break } }
    for _, r in ipairs(self.index:search(input, self.max_results)) do
        out[#out + 1] = { r.emoji, r.display, A.Commit }
    end
    return out
end

return M
