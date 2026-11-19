#!/usr/bin/env bash
set -euo pipefail

mode=${1:?Capture mode monitor or region required}
path=${2:?Absolute screenshot path required}
case "$mode" in
  monitor) action=screenshot-screen; wait_seconds=10 ;;
  region) action=screenshot; wait_seconds=120 ;;
  *) printf '%s\n' 'Capture mode must be monitor or region' >&2; exit 1 ;;
esac
[[ "$path" == /* ]] || { printf '%s\n' 'Screenshot path must be absolute' >&2; exit 1; }
mkdir -p -- "$(dirname -- "$path")"
temp_dir=$(mktemp -d -- "$(dirname -- "$path")/.niri-capture-XXXXXXXX")
temp="$temp_dir/selected.png"
# Removing the private directory also prevents a late native save after timeout.
trap 'rm -f -- "$temp"; rmdir -- "$temp_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
deadline=$((SECONDS + wait_seconds))
timeout "${wait_seconds}s" niri msg action "$action" --show-pointer false --path "$temp"
# Niri acknowledges the action before the image is saved. Region mode must never
# use screenshot-screen: it would leak the full output to clipboard watchers.
while ((SECONDS < deadline)); do
  if [[ -s "$temp" ]] && timeout 2s magick identify "$temp" >/dev/null 2>&1; then
    mv -f -- "$temp" "$path"
    exit 0
  fi
  sleep 0.1
done
if [[ "$mode" == region ]]; then
  printf '%s\n' 'Native selection cancelled or timed out after 120 seconds; press Escape if the picker is still open' >&2
  exit 2
fi
printf '%s\n' 'Niri did not produce a monitor screenshot within 10 seconds; check session logs' >&2
exit 1
