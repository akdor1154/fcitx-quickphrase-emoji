std = "lua53"
max_line_length = 110

-- fcitx calls handlers by global name.
files["fcitx5/lua/emojipicker/main.lua"] = {
    globals = { "emojipicker_on_key", "emojipicker_on_quickphrase" },
}

files["spec"] = { std = "+busted" }
