#!/usr/bin/env bash
set -euo pipefail

mode=toggle
if [[ ${1:-} == --status ]]; then
  mode=status
  shift
fi

app="${1:-}"
if [[ -z $app ]]; then
  app=$(command -v simplex-desktop || printf '%s\n' "$HOME/simplex")
fi
window_class="${2:-chat-simplex-desktop-MainKt}"
executable="${3:-}"
stash="special:simplex"

# The Arch package ships a wrapper in /usr/bin and a native launcher in /opt.
if [[ -z $executable ]]; then
  executable=$app
  if [[ $app -ef /usr/bin/simplex-desktop && -x /opt/simplex/bin/simplex ]]; then
    executable=/opt/simplex/bin/simplex
  fi
fi

hypr() {
  timeout --kill-after=1s 2s hyprctl "$@"
}

matches=$(hypr -j clients | jq -cr --arg class "$window_class" '
  .[] | select(.mapped != false and (.class == $class or .initialClass == $class))
  | select((.pid | type) == "number" and .pid > 0 and .pid == (.pid | floor))
  | select((.address | type) == "string" and (.address | test("^0x[0-9a-fA-F]+$")))
') || exit 2

address=
while IFS= read -r client; do
  [[ -n $client && -x $executable ]] || continue
  pid=$(jq -r '.pid' <<<"$client")
  [[ $pid =~ ^[1-9][0-9]*$ && /proc/$pid/exe -ef $executable ]] || continue
  address=$(jq -r '.address' <<<"$client")
  workspace=$(jq -r '.workspace.name' <<<"$client")
  break
done <<<"$matches"

if [[ $mode == status ]]; then
  if [[ -n $address ]]; then exit 0; fi
  exit 1
fi

if [[ -z $address ]]; then
  if [[ ! -x $app || ! -x $executable ]]; then
    notify-send "SimpleX Chat" "Set appPath and, for custom wrappers, appExecutable to the SimpleX executable."
    exit 1
  fi
  setsid -- "$app" >/dev/null 2>&1 &
  exit 0
fi

# Recheck the executable before acting in case the window's process exited.
[[ /proc/$pid/exe -ef $executable ]] || exit 1

if [[ $workspace == "$stash" ]]; then
  active_id=$(hypr -j activeworkspace | jq -r '.id')
  [[ $active_id =~ ^[1-9][0-9]*$ ]]
  hypr dispatch "hl.dsp.window.move({ workspace = '$active_id', follow = true, window = 'address:$address' })" >/dev/null
  hypr dispatch "hl.dsp.focus({ window = 'address:$address' })" >/dev/null
else
  hypr dispatch "hl.dsp.window.move({ workspace = '$stash', follow = false, window = 'address:$address' })" >/dev/null
fi
