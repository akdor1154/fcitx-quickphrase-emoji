# Emoji picker for fcitx5 Quick Phrase

This is a tiny lua addon that co-opts the Quick Phrase module into an improved emoji picker.

When Quick Phrase is activated by a special hard-coded hotkey (Super+e), this special emoji mode gets triggered.

It matches against the Unicode emoji database (read from your system), and doesn't need special `:desc:` codes.

It's thoroughly vibe-coded but at least I wrote this first paragraph and tried to keep the code size constrained.

## Requirements

On Debian or Ubuntu:

```sh
sudo apt install fcitx5-module-lua unicode-data unicode-cldr-core just
```

The addon reads:

- `/usr/share/unicode/emoji/emoji-test.txt` (unicode-data) for each emoji's
  exact character sequence, its name and its order
- `/usr/share/unicode/cldr/common/annotations*/<locale>.xml`
  (unicode-cldr-core) for localised names and search keywords

## Install

```sh
just install
```

This copies the addon to `~/.local/share/fcitx5`. Or build a .deb, which
installs to `/usr/share/fcitx5` and pulls in the requirements:

```sh
just deb
sudo apt install ./dist/fcitx5-quickphrase-emoji_*_all.deb
```

Don't keep both: a copy in `~/.local/share/fcitx5` takes precedence over the
package (`just uninstall` removes it).

Either way, add the emoji hotkey to Quick Phrase's trigger keys, so that it
opens Quick Phrase:

1. Open the fcitx5 configuration tool, go to Addons, and configure Quick Phrase.
2. Add `Super+E` to Trigger Key, next to the existing `Super+grave`.

Restart fcitx5 to load the addon.

## Use

Press Super+E, type, then choose with the number keys or Space.

# Implementation Notes

## Change the hotkey

The hotkey is hardcoded because the lua stuff from fcitx makes it too annoying to make it configurable.

The hotkey is set by `HOTKEY_SYM` and `HOTKEY_STATE` at the top of
`fcitx5/lua/emojipicker/app.lua`. `HOTKEY_SYM` is the key's keysym, from
`/usr/include/xkbcommon/xkbcommon-keysyms.h`. `HOTKEY_STATE` is the modifier
mask, using the values in `fcitx.KeyState`.

## How the hotkey works

fcitx5-lua cannot open Quick Phrase itself. Instead, the addon watches key
presses. fcitx runs Lua key watchers before Quick Phrase checks its trigger
keys, so the addon sees which trigger was pressed, notes whether it was the
emoji hotkey, and lets the key through. The Quick Phrase handler then answers
only in emoji mode. The next key that reaches the watcher after Quick Phrase
closes clears emoji mode.

## Troubleshooting

The addon logs at debug level. To see its messages:

```sh
fcitx5 -r --verbose='*=5' 2>&1 | grep emojipicker
```

On a successful start it logs `emojipicker: loaded N emoji` and the files it
read. Problems, such as missing data files, also go to fcitx5's standard error.

## Development

Install the tools with `sudo apt install lua5.3 lua-unit lua-check`.

```sh
just check            # luacheck, then the tests
just test -v -p App   # LuaUnit options: list each test, filter by name
just smoke            # load the addon in a headless fcitx5 and check for Lua errors
just deb              # build dist/*.deb with scripts/build-deb.sh
just version v1.0.0   # scripts/version.sh: write VERSION, commit, tag v1.0.0 (needs a clean tree)
```

The tests use LuaUnit and run with Lua 5.3, which is the version Debian and
Ubuntu's fcitx5-module-lua links against. Each `test/*_test.lua` file defines
global `Test*` tables, and `test/run.lua` loads them all.
