# SimpleX Chat — Omarchy bar widget

A one-click SimpleX Chat chip for the [Omarchy](https://omarchy.org) bar
(Quattro/Quickshell).

The SimpleX desktop app has no system tray on Wayland. This chip *is* the
tray:

- **Left click** launches the app if it is closed, or toggles its window
  between your current view and a hidden Hyprland special workspace
  (`special:simplex`) — the window keeps running in the background, connected
  and receiving messages, exactly like a tray app.
- **Right click** (or `R` via IPC) refreshes the running state.
- The chip glows **green** while the app runs in the background and stays
  dim/red when it is closed.

## Requirements

- Hyprland 0.55+ (uses the `hl.dsp.*` Lua dispatcher API)
- `hyprctl` and `jq` on `PATH`
- The SimpleX desktop app binary, by default expected at `~/simplex`

## Install

```
omarchy plugin clone CallMeBakugo/omarchy-simplex
omarchy bar put bakugo.simplex --section right
```

## Settings

| Setting | Default | Description |
| --- | --- | --- |
| `appPath` | `~/simplex` | Path to the SimpleX desktop binary |
| `windowClass` | `chat-simplex-desktop-MainKt` | Hyprland window class of the app |

## IPC

```
omarchy shell bakugo.simplex toggle   # same as clicking the chip
omarchy shell bakugo.simplex refresh
```

## Notes

Privacy: the widget runs entirely locally. It reads window state through
`hyprctl`, launches your local SimpleX binary, and stores no data. Nothing is
sent anywhere.

Hyprland 0.56.2 quirk: `hl.dsp.workspace.toggle_special` is a silent no-op
through `hyprctl`, so the toggle only uses `window.move` and `focus`, which
are verified working.

## License

MIT — see [LICENSE](LICENSE).