local config = require("emojipicker.config")

local function env(vars)
    return function(name)
        return vars[name]
    end
end

describe("config.path", function()
    it("uses XDG_CONFIG_HOME when set", function()
        assert.are.equal("/x/fcitx5/conf/emojipicker.conf",
            config.path(env({ XDG_CONFIG_HOME = "/x", HOME = "/home/u" })))
    end)

    it("falls back to ~/.config", function()
        assert.are.equal("/home/u/.config/fcitx5/conf/emojipicker.conf",
            config.path(env({ HOME = "/home/u" })))
        assert.are.equal("/home/u/.config/fcitx5/conf/emojipicker.conf",
            config.path(env({ XDG_CONFIG_HOME = "", HOME = "/home/u" })))
    end)
end)

describe("config.parse", function()
    it("gives the defaults for empty content", function()
        local cfg, warnings = config.parse("")
        assert.are.equal("Super+period", cfg.trigger_key)
        assert.are.same({}, warnings)
    end)

    it("reads TriggerKey, ignoring comments, sections and spacing", function()
        local cfg, warnings = config.parse(table.concat({
            "# emoji picker",
            "; another comment",
            "[Settings]",
            "",
            "  TriggerKey = Control+Alt+e  ",
        }, "\n"))
        assert.are.equal("Control+Alt+e", cfg.trigger_key)
        assert.are.same({}, warnings)
    end)

    it("keeps the default for an empty value", function()
        local cfg = config.parse("TriggerKey=")
        assert.are.equal("Super+period", cfg.trigger_key)
    end)

    it("warns about lines it does not understand", function()
        local cfg, warnings = config.parse("Colour=blue\nnot a setting\nTriggerKey=Super+e")
        assert.are.equal("Super+e", cfg.trigger_key)
        assert.are.same({
            "line 1: unknown setting Colour",
            "line 2: expected Key=Value",
        }, warnings)
    end)
end)

describe("config.load", function()
    it("gives the defaults when the file is missing", function()
        local cfg, warnings = config.load("spec/fixtures/no-such.conf")
        assert.are.equal("Super+period", cfg.trigger_key)
        assert.are.same({}, warnings)
    end)

    it("reads a file", function()
        local path = os.tmpname()
        local f = assert(io.open(path, "w"))
        f:write("TriggerKey=Super+semicolon\n")
        f:close()
        local cfg = config.load(path)
        os.remove(path)
        assert.are.equal("Super+semicolon", cfg.trigger_key)
    end)
end)
