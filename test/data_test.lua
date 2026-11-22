local lu = require("luaunit")
local data = require("emojipicker.data")

local FIXTURES = "test/fixtures"

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

local function emoji_column(list)
    local out = {}
    for i, e in ipairs(list) do
        out[i] = e.emoji
    end
    return out
end

TestParseEmojiTest = {}

function TestParseEmojiTest:setUp()
    self.entries = data.parse_emoji_test(read(FIXTURES .. "/emoji-test.txt"))
    self.found = by_emoji(self.entries)
end

function TestParseEmojiTest:testKeepsFullyQualifiedInFileOrder()
    lu.assertEquals(emoji_column(self.entries),
        { "😀", "❤️", "👍", "🔥", "🩴", "🚮", "🇦🇹", "🇦🇺" })
end

function TestParseEmojiTest:testKeepsFE0FInEmojiButNotInKey()
    lu.assertEquals(self.found["❤️"].emoji, "❤️")
    lu.assertEquals(self.found["❤️"].key, "❤")
end

function TestParseEmojiTest:testDropsSkinTonesAndComponents()
    lu.assertNil(self.found["👍🏽"])
    lu.assertNil(self.found["🏻"])
end

function TestParseEmojiTest:testRecordsNameAndGroup()
    lu.assertEquals(self.found["👍"].name, "thumbs up")
    lu.assertEquals(self.found["👍"].group, "People & Body")
end

TestParseCldr = {}

function TestParseCldr:setUp()
    self.en = read(FIXTURES .. "/cldr/annotations/en.xml")
    self.en_au = read(FIXTURES .. "/cldr/annotations/en_AU.xml")
end

function TestParseCldr:testReadsNamesAndKeywordsDecodingEntities()
    local c = data.parse_cldr(self.en)
    lu.assertEquals(c["👍"].name, "thumbs up")
    lu.assertEquals(c["👍"].keywords, { "+1", "good", "hand", "like", "thumb", "up", "yes" })
    lu.assertEquals(c["&"].name, "ampersand")
end

function TestParseCldr:testChildLocaleRenamesKeepingOldNameAndKeywords()
    local c = data.parse_cldr(self.en)
    data.parse_cldr(self.en_au, c)
    lu.assertEquals(c["🩴"].name, "thongs")
    lu.assertEquals(c["🩴"].keywords,
        { "beach", "flip flop", "sandal", "thong sandal", "jandal", "thongs" })
end

function TestParseCldr:testIgnoresInheritMarker()
    local c = data.parse_cldr(self.en)
    data.parse_cldr(self.en_au, c)
    lu.assertEquals(c["😀"].keywords, { "face", "grin", "grinning face" })
end

TestLocaleChain = {}

function TestLocaleChain:testPutsParentsFirst()
    lu.assertEquals(data.locale_chain("en_AU.UTF-8"), { "en", "en_001", "en_AU" })
    lu.assertEquals(data.locale_chain("en_US.UTF-8"), { "en", "en_US" })
    lu.assertEquals(data.locale_chain("de-CH"), { "de", "de_CH" })
    lu.assertEquals(data.locale_chain("fr"), { "fr" })
end

function TestLocaleChain:testFallsBackToEnglish()
    lu.assertEquals(data.locale_chain(nil), { "en" })
    lu.assertEquals(data.locale_chain("C"), { "en" })
    lu.assertEquals(data.locale_chain("POSIX"), { "en" })
end

TestFlagCode = {}

function TestFlagCode:testReadsRegionalIndicatorPairs()
    lu.assertEquals(data.flag_code("🇦🇺"), "au")
    lu.assertNil(data.flag_code("👍"))
    lu.assertNil(data.flag_code("🇦"))
end

TestLoad = {}

function TestLoad:setUp()
    self.list, self.info = data.load({
        emoji_test = FIXTURES .. "/emoji-test.txt",
        cldr_dir = FIXTURES .. "/cldr",
        locale = "en_AU.UTF-8",
    })
    self.found = by_emoji(self.list)
end

function TestLoad:testUsesCldrNameKeepingEmojiTestNameAsAlternative()
    lu.assertEquals(self.found["🩴"].name, "thongs")
    lu.assertEquals(self.found["🩴"].alt_name, "thong sandal")
end

function TestLoad:testAddsFlagCountryCodeAsKeyword()
    lu.assertEquals(self.found["🇦🇺"].keywords[1], "au")
end

function TestLoad:testAppendsCldrOnlyEmojiButNotPlainSymbols()
    lu.assertEquals(self.found["🫩"].name, "face with bags under eyes")
    lu.assertNil(self.found["&"])
    lu.assertEquals(self.info.cldr_only, 1)
end

function TestLoad:testListsFilesReadSkippingMissingOnes()
    lu.assertEquals(self.info.sources, {
        FIXTURES .. "/emoji-test.txt",
        FIXTURES .. "/cldr/annotations/en.xml",
        FIXTURES .. "/cldr/annotations/en_AU.xml",
    })
end

function TestLoad:testReportsMissingEmojiTest()
    local none, err = data.load({ emoji_test = FIXTURES .. "/missing.txt" })
    lu.assertNil(none)
    lu.assertStrContains(err, "unicode-data")
end
