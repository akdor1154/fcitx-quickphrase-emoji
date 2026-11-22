-- Read ~/.config/fcitx5/conf/emojipicker.conf.
--
-- The file holds Key=Value lines. Blank lines, comments (# or ;) and [Section]
-- headers are ignored. A missing file, or a missing setting, gives the default.

local M = {}

M.DEFAULTS = {
    trigger_key = "Super+period",
}

-- Setting name in the file -> field in the returned table.
local FIELDS = {
    TriggerKey = "trigger_key",
}

--- Path of the config file, following XDG_CONFIG_HOME as fcitx does.
-- @tparam[opt] function getenv defaults to os.getenv
function M.path(getenv)
    getenv = getenv or os.getenv
    local base = getenv("XDG_CONFIG_HOME")
    if not base or base == "" then
        base = (getenv("HOME") or "") .. "/.config"
    end
    return base .. "/fcitx5/conf/emojipicker.conf"
end

--- Parse config file content.
-- @treturn table settings, with defaults filled in
-- @treturn table list of warnings about lines that were ignored
function M.parse(content)
    local cfg, warnings = {}, {}
    for k, v in pairs(M.DEFAULTS) do
        cfg[k] = v
    end
    local n = 0
    for line in ((content or "") .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:find("^[#;]") and not line:find("^%[.*%]$") then
            local key, value = line:match("^([%w_]+)%s*=%s*(.-)$")
            if not key then
                warnings[#warnings + 1] = ("line %d: expected Key=Value"):format(n)
            elseif not FIELDS[key] then
                warnings[#warnings + 1] = ("line %d: unknown setting %s"):format(n, key)
            elseif value ~= "" then
                cfg[FIELDS[key]] = value
            end
        end
    end
    return cfg, warnings
end

--- Load settings from a file.
-- @treturn table settings
-- @treturn table warnings
function M.load(path)
    local f = io.open(path, "rb")
    if not f then
        return M.parse("")
    end
    local content = f:read("a")
    f:close()
    return M.parse(content)
end

return M
