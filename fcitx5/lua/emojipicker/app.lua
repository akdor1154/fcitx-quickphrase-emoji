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
local keys = require("emojipicker.keys")

local M = {}

local App = {}
App.__index = App

--- Create the picker and load the emoji data.
-- @tparam table opts
--   actions: fcitx.QuickPhraseAction (required)
--   trigger_key: key string, default "Super+period"
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

    local key, kerr = keys.parse(opts.trigger_key or "Super+period")
    if key then
        self.log("emojipicker: emoji hotkey is " .. key.text)
    else
        self.error("emojipicker: " .. kerr)
    end
    self.key = key

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
function App:on_key(sym, state, release)
    if release or keys.is_modifier(sym) then
        return false
    end
    self.emoji_mode = self.key ~= nil and keys.matches(self.key, sym, state)
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
