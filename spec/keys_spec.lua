local keys = require("emojipicker.keys")

local S = keys.STATE

describe("keys.parse", function()
    it("parses modifiers and named keys", function()
        local k = keys.parse("Super+period")
        assert.are.equal(0x2e, k.sym)
        assert.are.equal(S.Super, k.state)
    end)

    it("normalises like fcitx", function()
        -- Letters with a non-Shift modifier become upper case.
        local k = keys.parse("Control+Alt+e")
        assert.are.equal(0x45, k.sym)
        assert.are.equal(S.Ctrl | S.Alt, k.state)
        -- Shift+letter is just the capital letter.
        k = keys.parse("Shift+a")
        assert.are.equal(0x61, k.sym)
        assert.are.equal(0, k.state)
        -- Shift is dropped from other printable keys.
        k = keys.parse("Super+Shift+period")
        assert.are.equal(S.Super, k.state)
    end)

    it("accepts single characters, function keys and hex keysyms", function()
        assert.are.equal(0x3b, keys.parse("Super+;").sym)
        assert.are.equal(0xffbe, keys.parse("F1").sym)
        assert.are.equal(0x2e, keys.parse("Super+0x2e").sym)
    end)

    it("rejects what it cannot match", function()
        assert.is_nil(keys.parse(""))
        assert.is_nil(keys.parse("Hyper+a"))
        assert.is_nil(keys.parse("Super+nosuchkey"))
        assert.is_nil(keys.parse("Super+"))
    end)
end)

describe("keys.matches", function()
    local k = keys.parse("Super+period")

    it("matches the key as fcitx reports it", function()
        assert.is_true(keys.matches(k, 0x2e, S.Super))
    end)

    it("ignores lock keys and treats Super2 as Super", function()
        assert.is_true(keys.matches(k, 0x2e, S.Super | S.NumLock | S.CapsLock))
        assert.is_true(keys.matches(k, 0x2e, S.Super2))
    end)

    it("does not match other keys or modifiers", function()
        assert.is_false(keys.matches(k, 0x2e, 0))
        assert.is_false(keys.matches(k, 0x2e, S.Super | S.Ctrl))
        assert.is_false(keys.matches(k, 0x60, S.Super))
    end)
end)

describe("keys.is_modifier", function()
    it("recognises modifier keysyms", function()
        assert.is_true(keys.is_modifier(0xffeb)) -- Super_L
        assert.is_true(keys.is_modifier(0xffe1)) -- Shift_L
        assert.is_false(keys.is_modifier(0x2e))
    end)
end)
