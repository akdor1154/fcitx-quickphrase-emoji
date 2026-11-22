local data = require("emojipicker.data")

local FIXTURES = "spec/fixtures"

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("a")
    f:close()
    return s
end

local function by_emoji(list)
    local out = {}
    for _, e in ipairs(list) do
        out[e.emoji] = e
    end
    return out
end

describe("data.parse_emoji_test", function()
    local entries = data.parse_emoji_test(read(FIXTURES .. "/emoji-test.txt"))
    local found = by_emoji(entries)

    it("keeps fully-qualified emoji in file order", function()
        assert.are.same({ "😀", "❤️", "👍", "🔥", "🩴", "🚮", "🇦🇹", "🇦🇺" },
            (function()
                local t = {}
                for i, e in ipairs(entries) do
                    t[i] = e.emoji
                end
                return t
            end)())
    end)

    it("keeps U+FE0F in the emoji and strips it from the join key", function()
        assert.are.equal("❤️", found["❤️"].emoji)
        assert.are.equal("❤", found["❤️"].key)
    end)

    it("drops skin-tone variants and the Component group", function()
        assert.is_nil(found["👍🏽"])
        assert.is_nil(found["🏻"])
    end)

    it("records name and group", function()
        assert.are.equal("thumbs up", found["👍"].name)
        assert.are.equal("People & Body", found["👍"].group)
    end)
end)

describe("data.parse_cldr", function()
    it("reads names and keywords, decoding entities", function()
        local c = data.parse_cldr(read(FIXTURES .. "/cldr/annotations/en.xml"))
        assert.are.equal("thumbs up", c["👍"].name)
        assert.are.same({ "+1", "good", "hand", "like", "thumb", "up", "yes" }, c["👍"].keywords)
        assert.are.equal("ampersand", c["&"].name)
    end)

    it("lets a child locale rename, keeping the old name and all keywords", function()
        local c = data.parse_cldr(read(FIXTURES .. "/cldr/annotations/en.xml"))
        data.parse_cldr(read(FIXTURES .. "/cldr/annotations/en_AU.xml"), c)
        assert.are.equal("thongs", c["🩴"].name)
        assert.are.same(
            { "beach", "flip flop", "sandal", "thong sandal", "jandal", "thongs" },
            c["🩴"].keywords)
    end)

    it("ignores the inherit marker", function()
        local c = data.parse_cldr(read(FIXTURES .. "/cldr/annotations/en.xml"))
        data.parse_cldr(read(FIXTURES .. "/cldr/annotations/en_AU.xml"), c)
        assert.are.same({ "face", "grin", "grinning face" }, c["😀"].keywords)
    end)
end)

describe("data.locale_chain", function()
    it("puts parents first", function()
        assert.are.same({ "en", "en_001", "en_AU" }, data.locale_chain("en_AU.UTF-8"))
        assert.are.same({ "en", "en_US" }, data.locale_chain("en_US.UTF-8"))
        assert.are.same({ "de", "de_CH" }, data.locale_chain("de-CH"))
        assert.are.same({ "fr" }, data.locale_chain("fr"))
    end)

    it("falls back to English", function()
        assert.are.same({ "en" }, data.locale_chain(nil))
        assert.are.same({ "en" }, data.locale_chain("C"))
        assert.are.same({ "en" }, data.locale_chain("POSIX"))
    end)
end)

describe("data.flag_code", function()
    it("reads regional indicator pairs", function()
        assert.are.equal("au", data.flag_code("🇦🇺"))
        assert.is_nil(data.flag_code("👍"))
        assert.is_nil(data.flag_code("🇦"))
    end)
end)

describe("data.load", function()
    local list, info = data.load({
        emoji_test = FIXTURES .. "/emoji-test.txt",
        cldr_dir = FIXTURES .. "/cldr",
        locale = "en_AU.UTF-8",
    })
    local found = by_emoji(list)

    it("uses the CLDR name and keeps the emoji-test name as an alternative", function()
        assert.are.equal("thongs", found["🩴"].name)
        assert.are.equal("thong sandal", found["🩴"].alt_name)
    end)

    it("adds a flag's country code as a keyword", function()
        assert.are.equal("au", found["🇦🇺"].keywords[1])
    end)

    it("appends emoji that only CLDR knows, but not plain symbols", function()
        assert.are.equal("face with bags under eyes", found["🫩"].name)
        assert.is_nil(found["&"])
        assert.are.equal(1, info.cldr_only)
    end)

    it("lists the files it read, skipping missing ones", function()
        assert.are.same({
            FIXTURES .. "/emoji-test.txt",
            FIXTURES .. "/cldr/annotations/en.xml",
            FIXTURES .. "/cldr/annotations/en_AU.xml",
        }, info.sources)
    end)

    it("reports a missing emoji-test.txt", function()
        local none, err = data.load({ emoji_test = FIXTURES .. "/missing.txt" })
        assert.is_nil(none)
        assert.matches("unicode%-data", err)
    end)
end)
