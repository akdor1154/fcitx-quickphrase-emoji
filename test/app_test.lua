local lu = require("luaunit")
local app = require("emojipicker.app")

-- Same values as fcitx.QuickPhraseAction.
local ACTIONS = { Break = -1, Commit = 0 }

-- Keys as fcitx hands them to a watcher, already normalised.
local SUPER = 1 << 6
local KEY_E, GRAVE, LETTER_A, SUPER_L, SHIFT_L = 0x45, 0x60, 0x61, 0xffeb, 0xffe1

local function new_picker(overrides)
    local logs, errors = {}, {}
    local opts = {
        actions = ACTIONS,
        emoji_test = "test/fixtures/emoji-test.txt",
        cldr_dir = "test/fixtures/cldr",
        locale = "en_AU",
        log = function(msg) logs[#logs + 1] = msg end,
        error = function(msg) errors[#errors + 1] = msg end,
    }
    for k, v in pairs(overrides or {}) do
        opts[k] = v
    end
    return app.new(opts), logs, errors
end

TestApp = {}

function TestApp:testHotkeyIsSuperE()
    lu.assertEquals(app.HOTKEY_SYM, KEY_E)
    lu.assertEquals(app.HOTKEY_STATE, SUPER)
end

function TestApp:testLogsWhatItLoaded()
    local _, logs = new_picker()
    lu.assertStrContains(logs[1], "loaded 9 emoji")
end

function TestApp:testLeavesQuickPhraseAloneUntilEmojiKey()
    local picker = new_picker()
    lu.assertNil(picker:on_quickphrase("fire"))
end

function TestApp:testOffersEmojiAndStopsOtherProvidersAfterEmojiKey()
    local picker = new_picker()
    lu.assertFalse(picker:on_key(SUPER_L, 0, false))
    lu.assertFalse(picker:on_key(KEY_E, SUPER, false))
    local out = picker:on_quickphrase("fire")
    lu.assertEquals(out[1], { "", "", ACTIONS.Break })
    lu.assertEquals(out[2], { "🔥", "🔥 fire", ACTIONS.Commit })
end

function TestApp:testStaysInEmojiModeThroughReleasesAndModifiers()
    local picker = new_picker()
    picker:on_key(KEY_E, SUPER, false)
    picker:on_key(KEY_E, SUPER, true)
    picker:on_key(SUPER_L, 0, true)
    picker:on_key(SHIFT_L, 0, false)
    lu.assertNotNil(picker:on_quickphrase("fire"))
end

function TestApp:testLeavesEmojiModeOnNextOrdinaryKeyOrNormalTrigger()
    local picker = new_picker()
    picker:on_key(KEY_E, SUPER, false)
    picker:on_key(LETTER_A, 0, false)
    lu.assertNil(picker:on_quickphrase("fire"))

    picker:on_key(KEY_E, SUPER, false)
    picker:on_key(GRAVE, SUPER, false)
    lu.assertNil(picker:on_quickphrase("fire"))
end

function TestApp:testIgnoresEWithoutSuper()
    local picker = new_picker()
    picker:on_key(KEY_E, 0, false)
    lu.assertNil(picker:on_quickphrase("fire"))
end

function TestApp:testReportsMissingDataAndStaysOutOfTheWay()
    local picker, _, errors = new_picker({ emoji_test = "test/fixtures/missing.txt" })
    picker:on_key(KEY_E, SUPER, false)
    lu.assertNil(picker:on_quickphrase("fire"))
    lu.assertStrContains(errors[1], "unicode-data")
end
