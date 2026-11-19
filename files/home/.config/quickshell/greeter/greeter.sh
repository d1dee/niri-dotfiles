#!/bin/sh
set -eu

# This launcher is installed root-owned in /usr/local/bin. Never load login
# screen code or configuration from an interactive user's private home.
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=/var/lib/greetd
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export BNSPLIT_GREETER=1

# Session
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_CURRENT_DESKTOP=Hyprland

# Wayland stuff
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland

# pam_systemd supplies the greeter runtime directory. A private session bus
# prevents the greeter from sharing desktop services with a logged-in user.
exec dbus-run-session -- start-hyprland -- --config /usr/local/share/bnsplit-greeter/greeter/hyprland.lua
