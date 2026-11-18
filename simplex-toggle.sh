#!/usr/bin/env bash
set -euo pipefail

app="${1:-}"
if [[ -z $app ]]; then
  app=$(command -v simplex-desktop || printf '%s\n' "$HOME/simplex")
fi
window_class="${2:-chat-simplex-desktop-MainKt}"
stash="special:simplex"

client=$(hyprctl -j clients | jq -c --arg class "$window_class" '
  first(.[] | select(.class == $class or .initialClass == $class)) // null')
if [[ $client == null ]]; then
  if [[ ! -x $app ]]; then
    notify-send "SimpleX Chat" "Set the appPath to an executable SimpleX desktop launcher."
    exit 1
  fi
  setsid -- "$app" >/dev/null 2>&1 &
  exit 0
fi

address=$(jq -r '.address' <<<"$client")
workspace=$(jq -r '.workspace.name' <<<"$client")
[[ $address =~ ^0x[[:xdigit:]]+$ ]]

if [[ $workspace == "$stash" ]]; then
  active_id=$(hyprctl -j activeworkspace | jq -r '.id')
  [[ $active_id =~ ^[1-9][0-9]*$ ]]
  hyprctl dispatch "hl.dsp.window.move({ workspace = '$active_id', follow = true, window = 'address:$address' })" >/dev/null
  hyprctl dispatch "hl.dsp.focus({ window = 'address:$address' })" >/dev/null
else
  hyprctl dispatch "hl.dsp.window.move({ workspace = '$stash', follow = false, window = 'address:$address' })" >/dev/null
fi
