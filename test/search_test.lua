local lu = require("luaunit")
local data = require("emojipicker.data")
local search = require("emojipicker.search")

local function emojis(results)
    local out = {}
    for i, r in ipairs(results) do
        out[i] = r.emoji
    end
    return out
end

TestWords = {}

function TestWords:testLowerCasesDropsApostrophesSplitsOnPunctuation()
    lu.assertEquals(search.words("Woman’s hat"), { "womans", "hat" })
    lu.assertEquals(search.words("woman's"), { "womans" })
    lu.assertEquals(search.words("T-Rex"), { "t", "rex" })
    lu.assertEquals(search.words(":smile:"), { "smile" })
end

TestSearch = {}

function TestSearch:setUp()
    self.index = search.new(assert(data.load({
        emoji_test = "test/fixtures/emoji-test.txt",
        cldr_dir = "test/fixtures/cldr",
        locale = "en_AU",
    })))
end

function TestSearch:testEveryWordMustPrefixANameOrKeywordWordInAnyOrder()
    lu.assertEquals(emojis(self.index:search("thumbs up")), { "👍" })
    lu.assertEquals(emojis(self.index:search("up thu")), { "👍" })
    lu.assertEquals(emojis(self.index:search("thumbs down")), {})
end

function TestSearch:testExactKeywordBeatsNamePrefix()
    lu.assertEquals(emojis(self.index:search("lit")), { "🔥", "🚮" })
end

function TestSearch:testExactNameWordBeatsPrefix()
    lu.assertEquals(self.index:search("flag au")[1].emoji, "🇦🇺")
end

function TestSearch:testFindsAlternativeAndReplacedNames()
    lu.assertEquals(emojis(self.index:search("thong sandal")), { "🩴" })
    lu.assertEquals(emojis(self.index:search("jandal")), { "🩴" })
end

function TestSearch:testShowsEmojiWithName()
    lu.assertEquals(self.index:search("thongs")[1].display, "🩴 thongs")
end

function TestSearch:testCommitsFullyQualifiedForm()
    lu.assertEquals(self.index:search("red heart")[1].emoji, "❤️")
end

function TestSearch:testRespectsLimitAndIgnoresEmptyQueries()
    lu.assertEquals(#self.index:search("f", 1), 1)
    lu.assertEquals(self.index:search("  "), {})
end

-- Checks against the real system data, which the addon reads at run time.
TestSystemData = {}

local have_system_data = io.open(data.DEFAULT_EMOJI_TEST, "rb") ~= nil
local system_index

local function index_or_skip()
    lu.skipIf(not have_system_data, "needs the unicode-data and unicode-cldr-core packages")
    system_index = system_index or search.new(assert(data.load({ locale = "en_AU.UTF-8" })))
    return system_index
end

local FIRST_RESULT = {
    { "fire", "🔥" },
    { "lit", "🔥" },
    { "up thumbs", "👍" },
    { "heart", "❤️" },
    { "flag au", "🇦🇺" },
    { "tada", "🎉" },
    { "thongs", "🩴" },
}
for _, case in ipairs(FIRST_RESULT) do
    local query, expected = case[1], case[2]
    TestSystemData["testFirstResultFor_" .. query:gsub(" ", "_")] = function()
        lu.assertEquals(index_or_skip():search(query)[1].emoji, expected)
    end
end
