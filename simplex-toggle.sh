#!/usr/bin/env bash
# SimpleX Chat toggle for the Omarchy bar chip (bakugo.simplex).
# No window      -> launch the app.
# Window visible -> stash it on the hidden special workspace (still running).
# Window stashed -> move it back onto the active workspace and focus it.
# Usage: simplex-toggle.sh [app-path] [window-class]
#   app-path defaults to $HOME/simplex
#   window-class defaults to chat-simplex-desktop-MainKt
# Hyprland 0.56 uses the Lua dispatcher API (hl.dsp.*); toggle_special is a
# silent no-op through hyprctl in 0.56.2, so this only uses window.move,
# which is verified working on that build.
APP="${1:-$HOME/simplex}"
CLS="${2:-chat-simplex-desktop-MainKt}"
STASH=special:simplex

if ! command -v hyprctl >/dev/null || ! command -v jq >/dev/null; then
  notify-send -u critical -a simplex-toggle "hyprctl and jq are required" 2>/dev/null
  exit 1
fi

WIN=$(hyprctl -j clients | jq -r --arg c "$CLS" '
  first(.[] | select(.class == $c) | .address // empty) // empty')

if [ -z "$WIN" ]; then
  setsid "$APP" >/dev/null 2>&1 &
  exit 0
fi

WS=$(hyprctl -j clients | jq -r --arg a "$WIN" '
  first(.[] | select(.address == $a) | .workspace.name // empty) // empty')
ACTIVE_ID=$(hyprctl -j activeworkspace | jq -r .id)

if [ "$WS" = "$STASH" ]; then
  # Stashed: move it back here, following focus onto the workspace.
  hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ACTIVE_ID\", follow = true, window = 'address:$WIN' })" >/dev/null
  hyprctl dispatch "hl.dsp.focus({ window = 'class:$CLS' })" >/dev/null
else
  # Visible: stash it, keep it running in the background.
  hyprctl dispatch "hl.dsp.window.move({ workspace = '$STASH', follow = false, window = 'address:$WIN' })" >/dev/null
fi