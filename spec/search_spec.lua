local data = require("emojipicker.data")
local search = require("emojipicker.search")

local function emojis(results)
    local out = {}
    for i, r in ipairs(results) do
        out[i] = r.emoji
    end
    return out
end

describe("search.words", function()
    it("lower-cases, drops apostrophes and splits on punctuation", function()
        assert.are.same({ "womans", "hat" }, search.words("Woman’s hat"))
        assert.are.same({ "womans" }, search.words("woman's"))
        assert.are.same({ "t", "rex" }, search.words("T-Rex"))
        assert.are.same({ "smile" }, search.words(":smile:"))
    end)
end)

describe("search with fixture data", function()
    local index = search.new(assert(data.load({
        emoji_test = "spec/fixtures/emoji-test.txt",
        cldr_dir = "spec/fixtures/cldr",
        locale = "en_AU",
    })))

    it("needs every query word to prefix a name or keyword word, in any order", function()
        assert.are.same({ "👍" }, emojis(index:search("thumbs up")))
        assert.are.same({ "👍" }, emojis(index:search("up thu")))
        assert.are.same({}, emojis(index:search("thumbs down")))
    end)

    it("ranks an exact keyword above a name prefix", function()
        assert.are.same({ "🔥", "🚮" }, emojis(index:search("lit")))
    end)

    it("ranks an exact name word above a prefix", function()
        assert.are.equal("🇦🇺", index:search("flag au")[1].emoji)
    end)

    it("finds emoji by an alternative or replaced name", function()
        assert.are.same({ "🩴" }, emojis(index:search("thong sandal")))
        assert.are.same({ "🩴" }, emojis(index:search("jandal")))
    end)

    it("shows the emoji with its name", function()
        assert.are.equal("🩴 thongs", index:search("thongs")[1].display)
    end)

    it("commits the fully-qualified form", function()
        assert.are.equal("❤️", index:search("red heart")[1].emoji)
    end)

    it("respects the limit and ignores empty queries", function()
        assert.are.equal(1, #index:search("f", 1))
        assert.are.same({}, index:search("  "))
    end)
end)

local have_system_data = io.open(data.DEFAULT_EMOJI_TEST, "rb") ~= nil

describe("search with the system's Unicode data", function()
    if not have_system_data then
        pending("needs the unicode-data and unicode-cldr-core packages")
        return
    end

    local index = search.new(assert(data.load({ locale = "en_AU.UTF-8" })))

    local cases = {
        { "fire", "🔥" },
        { "lit", "🔥" },
        { "up thumbs", "👍" },
        { "heart", "❤️" },
        { "flag au", "🇦🇺" },
        { "tada", "🎉" },
        { "thongs", "🩴" },
    }
    for _, case in ipairs(cases) do
        it(("puts %s first for %q"):format(case[2], case[1]), function()
            assert.are.equal(case[2], index:search(case[1])[1].emoji)
        end)
    end
end)
