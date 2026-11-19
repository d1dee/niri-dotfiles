-- ========================================
--               AUTOSTART
-- ========================================

hl.on("hyprland.start", function()
	-- Portals use packaged D-Bus/systemd activation on Fedora.
	hl.exec_cmd("/usr/libexec/gsd-rfkill")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("$BN_SCRIPTS/qs-nothp")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("udiskie")
	hl.exec_cmd("qalc -exrates 1+1")
	hl.exec_cmd("kdeconnect-indicator")
	hl.exec_cmd("geary --gapplication-service")
	hl.exec_cmd("tmux set-environment -g HYPRLAND_INSTANCE_SIGNATURE $HYPRLAND_INSTANCE_SIGNATURE")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'bn-adw'")
	hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout :close")
	hl.exec_cmd("wl-paste --type text --watch sh -c 'bnclip store && qs ipc call clipboard reload'")
	hl.exec_cmd("wl-paste --type image --watch sh -c 'bnclip store && qs ipc call clipboard reload'")
	hl.exec_cmd("$BN_SCRIPTS/wallwatch")
	hl.exec_cmd("$BN_SCRIPTS/launch-geoclue")
	hl.exec_cmd("$BN_SCRIPTS/todoist daemon")
	hl.exec_cmd("$BN_SCRIPTS/xdg-desktop-portal-wallpaper-hypr")
	hl.exec_cmd("inotifywait -m -e modify $HOME/.config/hypr/hyprland/json --include '.*\\.json$' | while read -r _; do hyprctl reload; done")
end)

hl.on("hyprland.shutdown", function()
	hl.exec_cmd("pkill -f wallwatch")
	hl.exec_cmd("pkill -f geoclue")
	hl.exec_cmd("pkill -f todoist")
	hl.exec_cmd("pkill -f inotifywait")
end)
