-- ========================================
--         ENVIRONMENT VARIABLES
-- ========================================

local HOME = os.getenv("HOME")
local PATH = os.getenv("PATH")
hl.env("PATH",
    HOME .. "/.local/share/bnsplit/scripts:" ..
    HOME .. "/.spicetify:" ..
    HOME .. "/.cargo/bin:" ..
    HOME .. "/.local/bin:" ..
    HOME .. "/.local/share/pnpm:" ..
    HOME .. "/.local/share/flutter/bin:" ..
    HOME .. "/.pub-cache/bin:" ..
    HOME .. "/.config/herd-lite/bin:" ..
    "/usr/lib64/qt6/bin:" ..
    "/opt/android-sdk/cmdline-tools/latest/bin:" ..
    "/opt/android-sdk/platform-tools:" ..
    "/opt/android-sdk/emulator:" ..
    PATH
)
hl.env("BN_SCRIPTS", HOME .. "/.local/share/bnsplit/scripts")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("ELECTRO_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_SCALE", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("BROWSER", "firefox")
hl.env("_CHROMIUM_USE_WAYLAND", "1")
hl.env("GTK_THEME", "bn-adw")
hl.env("GTK_THEME", "bn-adw", true)

-- create an empty secrets.lua on first run so the require below never fails
local secrets_path = HOME .. "/.config/hypr/hyprland/lua/secrets.lua"
local f = io.open(secrets_path, "r")
if f then
    f:close()
else
    f = io.open(secrets_path, "w")
    if f then f:close() end
end

pcall(function() require("hyprland.lua.secrets") end)
