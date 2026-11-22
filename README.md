# Emoji picker for fcitx5 Quick Phrase

A Lua addon for fcitx5 that adds an emoji mode to Quick Phrase. Press the emoji
hotkey, type words from an emoji's name or keywords, and pick from the list.

- Each typed word must be the start of a word in the emoji's name or keywords,
  in any order: `thu up`, `up thumbs` and `like` all find 👍.
- Names and keywords come from the system's Unicode data, in your locale. With
  `en_AU`, `thongs` finds 🩴.
- In emoji mode the built-in Quick Phrase tables and spelling suggestions are
  hidden. The normal Quick Phrase trigger behaves as before.

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

This copies the addon to `~/.local/share/fcitx5`. Then add the emoji hotkey to
Quick Phrase's trigger keys, so that it opens Quick Phrase:

1. Open the fcitx5 configuration tool, go to Addons, and configure Quick Phrase.
2. Add `Super+period` to Trigger Key, next to the existing `Super+grave`.

Or stop fcitx5 and edit `~/.config/fcitx5/conf/quickphrase.conf`:

```ini
[TriggerKey]
0=Super+grave
1=Super+period
```

Restart fcitx5 to load the addon:

```sh
fcitx5 -r -d
```

## Use

Press Super+period, type, then choose with the number keys or Space. Enter
commits what you typed, as in normal Quick Phrase.

## Change the hotkey

Create `~/.config/fcitx5/conf/emojipicker.conf`:

```ini
TriggerKey=Super+semicolon
```

Keys use fcitx's names: modifiers `Control`, `Alt`, `Shift` and `Super`, joined
with `+` to a key name such as `period`, `semicolon`, `e` or `F12`. Put the same
key in Quick Phrase's trigger keys, then restart fcitx5. Without the file, the
hotkey is `Super+period`.

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

On a successful start it logs the emoji hotkey, then `emojipicker: loaded N
emoji` and the files it read. Problems, such as missing data files, an unknown
key name or an unknown setting in the config file, also go to fcitx5's standard
error.

## Development

```sh
just check   # luacheck and busted
just smoke   # load the addon in a headless fcitx5 and check for Lua errors
```

The tests run with Lua 5.3, which is the version Debian and Ubuntu's
fcitx5-module-lua links against.
