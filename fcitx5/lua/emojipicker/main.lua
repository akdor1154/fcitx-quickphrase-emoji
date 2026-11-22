-- fcitx5 entry point. Kept thin: the logic is in app.lua.

local fcitx = require("fcitx")

-- Make require("emojipicker.x") find the files next to this one.
local lua_dir = debug.getinfo(1, "S").source:match("^@(.+)/[^/]+/[^/]+$")
if lua_dir then
    package.path = lua_dir .. "/?.lua;" .. package.path
end

local app = require("emojipicker.app")
local config = require("emojipicker.config")

-- fcitx.log only shows at debug level, so also write problems to stderr.
local function report(msg)
    fcitx.log(msg)
    io.stderr:write(msg, "\n")
end

local config_path = config.path()
local settings, warnings = config.load(config_path)
for _, w in ipairs(warnings) do
    report("emojipicker: " .. config_path .. ": " .. w)
end

local function system_locale()
    for _, var in ipairs({ "LC_ALL", "LC_MESSAGES", "LANG" }) do
        local v = os.getenv(var)
        if v and v ~= "" then
            return v
        end
    end
end

local picker = app.new({
    actions = fcitx.QuickPhraseAction,
    trigger_key = settings.trigger_key,
    locale = system_locale(),
    log = fcitx.log,
    error = report,
})

-- fcitx calls handlers by global name.
function emojipicker_on_key(sym, state, release)
    return picker:on_key(sym, state, release)
end

function emojipicker_on_quickphrase(input)
    return picker:on_quickphrase(input)
end

fcitx.watchEvent(fcitx.EventType.KeyEvent, "emojipicker_on_key")
fcitx.addQuickPhraseHandler("emojipicker_on_quickphrase")
