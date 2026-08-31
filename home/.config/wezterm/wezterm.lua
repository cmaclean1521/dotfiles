local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
-- Opacity is paired with macos_window_background_blur, which only exists on
-- macOS and is cheap there thanks to the native compositor. Windows has no
-- equivalent blur, so the same opacity setting just forces expensive
-- per-frame alpha-compositing with nothing to show for it - the likely cause
-- of typing lag and inconsistent cursor-blink rendering reported there.
local IS_WINDOWS = wezterm.target_triple:find("windows") ~= nil
config.window_background_opacity = IS_WINDOWS and 1.0 or 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
-- macOS gets a chrome-less window (no title bar); Windows keeps the normal
-- title bar with minimize/maximize/close, since there's no OS-level way to
-- close a decoration-less window there the way macOS's menu bar allows.
config.window_decorations = IS_WINDOWS and "TITLE | RESIZE" or "RESIZE"
-- Without this, WezTerm falls back to %COMSPEC% (cmd.exe) on Windows, since
-- there's no login-shell concept to resolve like there is on macOS/Linux.
if IS_WINDOWS then
	config.default_prog = { "powershell.exe" }
end

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		-- Same reasoning as the base window_background_opacity above: don't
		-- reintroduce alpha-compositing on Windows just to dim on unfocus.
		opacity = IS_WINDOWS and nil or UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

return config
