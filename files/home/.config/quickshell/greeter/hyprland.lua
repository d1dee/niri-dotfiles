hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
	-- Greetd.launch exits qs after acknowledgement. Only then release this
	-- greeter compositor/VT; never kill other Hyprland sessions by process name.
	hl.exec_cmd("qs -p /usr/local/share/bnsplit-greeter/Greeter.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { repeating = true })

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

hl.config({
	general = {
		gaps_in = 0,
		gaps_out = 0,
		border_size = 0,
	},

	decoration = {
		rounding = 0,
		blur = {
			enabled = false,
		},
	},

	animations = {
		enabled = false,
	},

	misc = {
		force_default_wallpaper = false,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		background_color = "0x000000",
	},

	input = {
		kb_layout = "us",
		kb_variant = "altgr-intl",
		kb_options = "caps:escape",
		follow_mouse = true,
		repeat_rate = 50,
		repeat_delay = 250,
		accel_profile = "adaptive",
		sensitivity = 0.125,

		touchpad = {
			natural_scroll = true,
			disable_while_typing = true,
		},
	},
})
