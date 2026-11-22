local app = require("emojipicker.app")
local keys = require("emojipicker.keys")

-- Same values as fcitx.QuickPhraseAction.
local ACTIONS = { Break = -1, Commit = 0 }

local SUPER = keys.STATE.Super
local PERIOD, GRAVE, LETTER_A, SUPER_L = 0x2e, 0x60, 0x61, 0xffeb

local function new_picker(overrides)
    local logs = {}
    local opts = {
        actions = ACTIONS,
        emoji_test = "spec/fixtures/emoji-test.txt",
        cldr_dir = "spec/fixtures/cldr",
        locale = "en_AU",
        log = function(msg) logs[#logs + 1] = msg end,
    }
    for k, v in pairs(overrides or {}) do
        opts[k] = v
    end
    return app.new(opts), logs
end

describe("app", function()
    it("logs the hotkey and what it loaded", function()
        local _, logs = new_picker()
        assert.are.equal("emojipicker: emoji hotkey is Super+period", logs[1])
        assert.matches("loaded 9 emoji", logs[2])
    end)

    it("leaves Quick Phrase alone until the emoji key is pressed", function()
        local picker = new_picker()
        assert.is_nil(picker:on_quickphrase("fire"))
    end)

    it("offers emoji and stops other providers after the emoji key", function()
        local picker = new_picker()
        assert.is_false(picker:on_key(SUPER_L, 0, false))
        assert.is_false(picker:on_key(PERIOD, SUPER, false))
        local out = picker:on_quickphrase("fire")
        assert.are.same({ "", "", ACTIONS.Break }, out[1])
        assert.are.same({ "🔥", "🔥 fire", ACTIONS.Commit }, out[2])
    end)

    it("stays in emoji mode through key releases and modifier presses", function()
        local picker = new_picker()
        picker:on_key(PERIOD, SUPER, false)
        picker:on_key(PERIOD, SUPER, true)
        picker:on_key(SUPER_L, 0, true)
        assert.is_not_nil(picker:on_quickphrase("fire"))
    end)

    it("leaves emoji mode on the next ordinary key or the normal trigger", function()
        local picker = new_picker()
        picker:on_key(PERIOD, SUPER, false)
        picker:on_key(LETTER_A, 0, false)
        assert.is_nil(picker:on_quickphrase("fire"))

        picker:on_key(PERIOD, SUPER, false)
        picker:on_key(GRAVE, SUPER, false)
        assert.is_nil(picker:on_quickphrase("fire"))
    end)

    it("uses a configured trigger key", function()
        local picker = new_picker({ trigger_key = "Control+Alt+e" })
        picker:on_key(0x65, keys.STATE.Ctrl | keys.STATE.Alt, false)
        assert.is_not_nil(picker:on_quickphrase("fire"))
    end)

    it("reports missing data and stays out of the way", function()
        local errors = {}
        local picker = new_picker({
            emoji_test = "spec/fixtures/missing.txt",
            error = function(msg) errors[#errors + 1] = msg end,
        })
        picker:on_key(PERIOD, SUPER, false)
        assert.is_nil(picker:on_quickphrase("fire"))
        assert.matches("unicode%-data", errors[1])
    end)

    it("reports a bad trigger key", function()
        local errors = {}
        local picker = new_picker({
            trigger_key = "Hyper+e",
            error = function(msg) errors[#errors + 1] = msg end,
        })
        picker:on_key(PERIOD, SUPER, false)
        assert.is_nil(picker:on_quickphrase("fire"))
        assert.matches("Hyper", errors[1])
    end)
end)
