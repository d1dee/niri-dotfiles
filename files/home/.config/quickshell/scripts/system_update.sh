#!/usr/bin/env bash

# Arguments are package names; no arguments upgrades the whole system.
if sudo dnf upgrade --assumeyes -- "$@"; then
  status=0
  notify-send --app-name=Updates --icon=update-manager "Update finished" "All updates completed successfully."
  qs ipc call niri focusApp quickshell-system-update >/dev/null 2>&1
  qs ipc call update refresh >/dev/null
else
  status=$?
  notify-send --app-name=Updates --icon=update-manager "Update failed" "Some updates did not complete."
  qs ipc call niri focusApp quickshell-system-update >/dev/null 2>&1
  qs ipc call update refresh >/dev/null
fi

echo -en "\nPress any key to exit..."
read -n1 -s -r
exit "$status"
