# Keyboard layout for the Omarchy bar, seat-wide

[![Ko-fi](https://img.shields.io/badge/Ko--fi-support-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/mike_g)

The stock Omarchy keyboard-layout widget with two additions:

1. **Switching moves the whole seat.** A click runs
   `hyprctl switchxkblayout all next` instead of switching the one keyboard
   the label describes. With fcitx5 running, its virtual keyboard holds the
   seat's main flag; switching a single physical keyboard then changes the
   label but not what you type.
2. **A layout popup.** Right click on the label, or its `SUPER+CTRL+<n>`
   panel hotkey, lists the configured layouts with their names; click or use
   the arrows and Enter to pick one, Escape to close.

Everything else — the label, keyboard detection, polling — is the stock
widget, imported from `/usr/share/omarchy` rather than copied, so Omarchy
updates to it apply here as is.

## Install

```sh
omarchy plugin add https://github.com/yesm1ke/omarchy-plugin-keyboard-layout --enable
omarchy plugin disable omarchy.keyboard-layout   # the stock widget it replaces
```

## How it works

`KeyboardLayout.qml` extends the stock `KeyboardLayout` from
`/usr/share/omarchy/shell/plugins/bar/widgets/` and overrides its
`cycleLayout()` function; the stock button keeps calling it. The popup reads
`hyprctl -j devices` for the configured layouts and the active one, and
`xkbcli list` for their names (`LayoutNames.js`).

It relies on the stock widget exposing `cycleLayout()`, `refresh()`,
`keyboardName` and `layoutFull`; check those first if it breaks after an
Omarchy update.

## License

MIT, see [LICENSE](LICENSE).
