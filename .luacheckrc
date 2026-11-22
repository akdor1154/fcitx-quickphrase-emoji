std = "lua53"
max_line_length = 110

-- fcitx calls handlers by global name.
files["fcitx5/lua/emojipicker/main.lua"] = {
    globals = { "emojipicker_on_key", "emojipicker_on_quickphrase" },
}

-- LuaUnit finds tests in global tables named Test*, and test methods take an
-- implicit self whether they use it or not.
files["test"] = { allow_defined_top = true, self = false }
