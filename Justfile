data_home := env("XDG_DATA_HOME", env("HOME") / ".local/share")

# Lint and test
check: lint test

# Run the tests (pass LuaUnit options, e.g. just test -v -p Search)
test *args:
    lua test/run.lua {{ args }}

# Run luacheck
lint:
    luacheck fcitx5 test

# Copy the addon into fcitx5's data directory
install dest=(data_home / "fcitx5"):
    install -Dm644 fcitx5/addon/emojipicker.conf {{ dest }}/addon/emojipicker.conf
    install -Dm644 -t {{ dest }}/lua/emojipicker fcitx5/lua/emojipicker/*.lua
    @echo "Installed to {{ dest }}. Restart fcitx5 to load it: fcitx5 -r -d"

# Remove the addon from fcitx5's data directory
uninstall dest=(data_home / "fcitx5"):
    rm -f {{ dest }}/addon/emojipicker.conf
    rm -rf {{ dest }}/lua/emojipicker

# Load the addon in a headless fcitx5 and check for Lua errors
smoke:
    #!/usr/bin/env bash
    set -uo pipefail
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    {{ just_executable() }} --quiet install "$tmp/data/fcitx5" > /dev/null
    mkdir -m 700 "$tmp/run"
    XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_RUNTIME_DIR="$tmp/run" \
        dbus-run-session -- timeout 3 fcitx5 --disable=all \
        --enable=keyboard,luaaddonloader,quickphrase,emojipicker --verbose='*=5' \
        > "$tmp/log" 2>&1
    grep -E 'emojipicker|lua_pcall|luaL_' "$tmp/log"
    if grep -qE 'lua_pcall|luaL_' "$tmp/log" || ! grep -q 'emojipicker: loaded' "$tmp/log"; then
        exit 1
    fi
