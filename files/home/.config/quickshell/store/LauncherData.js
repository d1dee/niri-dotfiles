.pragma library

const pages = [
    { id: "page.01", name: "Clipboard", desc: "Browse clipboard history", icon: "content_paste", iconType: "material", page: "clipboard" },
    { id: "page.02", name: "Wallpaper", desc: "Change the desktop wallpaper", icon: "image", iconType: "material", page: "wallpaper" },
    { id: "page.03", name: "Wallhaven", desc: "Browse online Wallhaven wallpapers", icon: "image", iconType: "material", page: "wallhaven" },
    { id: "page.04", name: "Files", desc: "Browse and search files", icon: "folder", iconType: "material", page: "files" },
    { id: "page.05", name: "Keybinds", desc: "Show niri's native hotkey overlay", icon: "keyboard", iconType: "material", page: "keybinds" },
    { id: "page.06", name: "Calculator", desc: "Calculator powered by Qalculate!", icon: "function", iconType: "material", page: "calculator" },
    { id: "page.07", name: "Tasks", desc: "Manage Todoist tasks", icon: "check_circle", iconType: "material", page: "tasks" },
    { id: "page.08", name: "Emojis", desc: "Browse and copy emojis", icon: "mood", iconType: "material", page: "emojis" },
    { id: "page.09", name: "Processes", desc: "List and kill running processes", icon: "cancel", iconType: "material", page: "processes" },
    { id: "page.10", name: "Monitors", desc: "Configure monitor layout and settings", icon: "desktop_windows", iconType: "material", page: "monitors" },
    { id: "page.11", name: "Translate", desc: "Translate text and phrases", icon: "translate", iconType: "material", page: "translate" },
    { id: "page.12", name: "Web Search", desc: "Search the web", icon: "public", iconType: "material", page: "websearch" },
    { id: "page.13", name: "Commands", desc: "Execute shell commands", icon: "terminal", iconType: "material", page: "commands" },
    { id: "page.14", name: "Unsplash", desc: "Browse online Unsplash photos", icon: "image", iconType: "material", page: "unsplash" },
];

const commands = [
    // --- Wallpaper ---
    { id: "command.01", name: "Random Wallpaper", desc: "Apply a random desktop background", icon: "shuffle", iconType: "material", exec: ["sh", "-c", "$BN_SCRIPTS/select-wallpaper --random"], popup: { type: "info", title: "Applying Random Wallpaper", message: "", duration: 2000 } },
    { id: "command.02", name: "Save Temporary Wallpaper", desc: "Save the temporary wallpaper to your collection", icon: "image", iconType: "material", actionType: "save_tmp_wallpaper", isTemporaryWallpaperCheck: true, popup: { type: "info", title: "Saving Wallpaper", message: "", duration: 2000 } },
    { id: "command.28", name: "Save Temporary Wallpaper as Hidden", desc: "Save the temporary wallpaper to your collection as a hidden entry", icon: "visibility_off", iconType: "material", actionType: "save_tmp_wallpaper_hidden", isTemporaryWallpaperCheck: true, popup: { type: "info", title: "Saving Hidden Wallpaper", message: "", duration: 2000 } },

    // --- Screen recording ---
    { id: "command.03", name: "Toggle Recording", desc: "Start or stop screen recording", icon: "videocam", iconType: "material", actionType: "toggle_recording" },

    // --- Color picking ---
    { id: "command.04", name: "Pick Color (Hex)", desc: "Pick a color from the screen (Hex format)", icon: "colorize", iconType: "material", actionType: "colorpick", args: ["hex"] },
    { id: "command.05", name: "Pick Color (RGB)", desc: "Pick a color from the screen (RGB format)", icon: "colorize", iconType: "material", actionType: "colorpick", args: ["rgb"] },

    // --- Visual toggles: blur ---
    { id: "command.07", name: "Toggle Lockscreen Blur", desc: "Toggle blur effect on the lockscreen", icon: "blur_on", iconType: "material", actionType: "toggle_lockscreen_blur" },

    // --- Visual toggles: shadows ---
    { id: "command.08", name: "Toggle Window Shadows", desc: "Toggle shadows for windows", icon: "layers", iconType: "material", actionType: "toggle_window_shadows" },
    { id: "command.09", name: "Toggle Layer Shadows", desc: "Toggle shadows for UI layers", icon: "layers", iconType: "material", actionType: "toggle_layer_shadows" },

    // --- Visual toggles: transparency ---
    { id: "command.10", name: "Toggle Window Transparency", desc: "Toggle transparency for windows", icon: "water_drop", iconType: "material", actionType: "toggle_window_transparency" },
    { id: "command.11", name: "Toggle Layer Transparency", desc: "Toggle transparency for UI layers", icon: "water_drop", iconType: "material", actionType: "toggle_layer_transparency" },

    // --- Visual toggles: layout ---
    { id: "command.12", name: "Toggle Gaps", desc: "Toggle larger niri layout gaps", icon: "border_outer", iconType: "material", actionType: "toggle_outer_gaps" },

    // --- Visual toggles: rounding ---
    { id: "command.13", name: "Toggle Rounded Corners", desc: "Toggle shell and windows rounded corners", icon: "rounded_corner", iconType: "material", actionType: "toggle_rounded_corners" },

    // --- Visual toggles: bar ---
    { id: "command.14", name: "Toggle Compact Bar", desc: "Always use the compact bar", icon: "toolbar", iconType: "material", actionType: "toggle_compact_bar" },

    // --- System: updates & backup ---
    { id: "command.16", name: "Update", desc: "Check and perform system updates", icon: "update", iconType: "material", actionType: "system_update", isUpdateCheck: true},
    { id: "command.17", name: "Backup", desc: "Backup system configuration and data", icon: "cloud_upload", iconType: "material", exec: ["systemctl", "start", "bkp.service"], popup: { type: "info", title: "Backup Started", message: "", duration: 2000 } },

    // --- Session / power ---
    { id: "command.18", name: "Lock", desc: "Lock the screen", icon: "lock", iconType: "material", exec: ["sh", "-c", "exec \"$HOME/.local/share/bnsplit/scripts/niri-lock\""] },
    { id: "command.19", name: "Suspend", desc: "Lock, then suspend the system", icon: "dark_mode", iconType: "material", exec: ["sh", "-c", "exec \"$HOME/.local/share/bnsplit/scripts/niri-lock\" --suspend"] },
    { id: "command.20", name: "Logout", desc: "Exit niri session", icon: "logout", iconType: "material", confirm: ["Logout", "Are you sure you want to exit niri?", "Cancel", "Logout", "niri msg action quit --skip-confirmation"] },
    { id: "command.21", name: "Restart", desc: "Reboot the system", icon: "rotate_right", iconType: "material", confirm: ["Restart", "Are you sure you want to restart?", "Cancel", "Restart", "reboot"] },
    { id: "command.22", name: "Restart to BIOS", desc: "Reboot into firmware setup", icon: "build", iconType: "material", confirm: ["Restart to BIOS", "Are you sure you want to restart into BIOS/UEFI setup?", "Cancel", "Restart", "systemctl reboot --firmware-setup"] },
    { id: "command.23", name: "Shutdown", desc: "Power off the system", icon: "power_settings_new", iconType: "material", confirm: ["Shutdown", "Are you sure you want to power off?", "Cancel", "Shutdown", "shutdown now"] },

    // --- Packages ---
    { id: "command.24", name: "Install Packages", desc: "Install new packages", icon: "download", iconType: "material", exec: ["sh", "-c", "$BN_SCRIPTS/bnpkgi --float"] },
    { id: "command.25", name: "Uninstall Packages", desc: "Remove installed packages", icon: "delete", iconType: "material", exec: ["sh", "-c", "$BN_SCRIPTS/bnpkgr --float"] },

    // --- QuickShell ---
    { id: "command.26", name: "Reload Shell", desc: "Reload the QuickShell configuration", icon: "restart_alt", iconType: "material", actionType: "reload_quickshell" },

    // --- Wallpaper ---
    { id: "command.27", name: "Upscale Wallpaper (2x)", desc: "2x-upscale and re-apply current wallpaper", icon: "hd", iconType: "material", exec: ["sh", "-c", "$BN_SCRIPTS/upscale-wallpaper"], popup: { type: "info", title: "Upscaling Wallpaper", message: "Please wait a few seconds...", duration: -1 } },
];
