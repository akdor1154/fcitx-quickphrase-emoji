-- Run the tests from the repository root:
--   lua test/run.lua            all tests
--   lua test/run.lua -v         list each test
--   lua test/run.lua -p Search  only tests whose name contains "Search"

package.path = "fcitx5/lua/?.lua;test/?.lua;" .. package.path

local lu = require("luaunit")

for _, name in ipairs({ "data", "search", "app" }) do
    require(name .. "_test")
end

os.exit(lu.LuaUnit.run())
