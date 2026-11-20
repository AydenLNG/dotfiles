-- ~/.config/hypr/rice.lua
-- Glass look + wallpaper-synced colours. Loaded at the END of hyprland.lua with:
--     require("rice")
-- Anything set here overrides the same setting earlier in hyprland.lua.

---- SETTINGS YOU MIGHT CHANGE ----

-- Main modifier key. Use "ALT" on keyboards without a Windows/Super key.
local mod = "SUPER"

local home = os.getenv("HOME")
local rice = home .. "/.config/rice"

---- COLOURS (written by rice/theme-sync.py whenever the wallpaper changes) ----

local colors = { active = "rgba(86aaecee)", inactive = "rgba(1f223388)" }
do
    local ok, c = pcall(dofile, home .. "/.config/hypr/colors.lua")
    if ok and type(c) == "table" then colors = c end
end

---- AUTOSTART ----

hl.on("hyprland.start", function()
    hl.exec_cmd(rice .. "/wallpaper.sh restore")   -- starts awww-daemon + last wallpaper
    hl.exec_cmd(rice .. "/gamemode.sh --reset")    -- game mode starts off after login
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")                                         -- notifications + notification centre
    hl.exec_cmd("nm-applet --indicator")                          -- Wi-Fi icon in the bar's tray
    hl.exec_cmd("wl-paste --type text --watch cliphist store")    -- clipboard history (text)
    hl.exec_cmd("wl-paste --type image --watch cliphist store")   -- clipboard history (images)
end)

---- LOOK: gaps, borders, glass blur ----

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 18,
        border_size = 2,
        col = {
            active_border   = colors.active,
            inactive_border = colors.inactive,
        },
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 14,
        blur = {
            enabled = true,
            size = 4,        -- how far each pass spreads
            passes = 1,      -- more passes = smoother, heavier frosted glass
            vibrancy = 0.18,
        },
        shadow = {
            enabled = true,
            range = 18,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

---- ANIMATIONS ----

hl.curve("smooth", { type = "bezier", points = { {0.16, 1.0}, {0.3, 1.0} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "border",     enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "smooth", style = "slidefade" })

---- BLUR BEHIND THE BAR, LAUNCHER AND NOTIFICATIONS ----
-- Terminals get their glass from kitty's own transparency (kitty/colors.conf),
-- which keeps text sharp while the background is blurred.

hl.layer_rule({ match = { namespace = "waybar" },        blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.2 })   -- popups
hl.layer_rule({ match = { namespace = "swaync-control-center" },       blur = true, ignore_alpha = 0.2 })   -- notification centre
hl.layer_rule({ match = { namespace = "rofi" },          blur = true, ignore_alpha = 0.2 })   -- launcher, menus, wallpaper picker

---- KEYBINDS ----

-- One bad bind must not break the whole config.
local function bind(keys, ...)
    local ok, err = pcall(hl.bind, keys, ...)
    if not ok then print("rice.lua: skipped bind '" .. tostring(keys) .. "': " .. tostring(err)) end
end

-- Super+W is left free on purpose. Random wallpaper: right-click the bar's wallpaper icon.
bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(rice .. "/wallpaper.sh pick"))   -- preview picker
bind(mod .. " + Escape",    hl.dsp.exec_cmd(rice .. "/power-menu.sh"))
bind(mod .. " + I",         hl.dsp.exec_cmd(rice .. "/settings-menu.sh"))
bind(mod .. " + slash",     hl.dsp.exec_cmd(rice .. "/keybinds.sh"))       -- keybind cheat sheet
bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(rice .. "/help.sh"))           -- troubleshooting notes
bind(mod .. " + N",         hl.dsp.exec_cmd("swaync-client -t -sw"))       -- notification centre
bind(mod .. " + G",         hl.dsp.exec_cmd(rice .. "/gamemode.sh"))       -- game mode on/off
-- Mod+E (file manager) comes from your hyprland.lua; the installer points it at thunar.
-- Mod+V is the default "toggle floating", so clipboard history uses Mod+Shift+V.
bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(rice .. "/clipboard.sh"))
bind("Print",               hl.dsp.exec_cmd(rice .. "/screenshot.sh area"))
bind("SHIFT + Print",       hl.dsp.exec_cmd(rice .. "/screenshot.sh full"))
-- Same screenshots for keyboards without a Print key (Mod+Shift+S is taken by the default config).
bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd(rice .. "/screenshot.sh area"))
bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(rice .. "/screenshot.sh full"))

---- SETTINGS APPS OPEN AS FLOATING WINDOWS ----

local floating = {
    "pavucontrol", "blueman-manager", "nm-connection-editor",
    "nwg-look", "nwg-displays", "file-roller", "FileRoller", "rice-help",
}
for _, app in ipairs(floating) do
    local ok, err = pcall(hl.window_rule, {
        name = "rice-float-" .. app,
        match = { class = ".*" .. app .. ".*" },
        float = true,
        center = true,
    })
    if not ok then print("rice.lua: skipped float rule '" .. app .. "': " .. tostring(err)) end
end

---- GAME MODE (Mod+G) ----
-- If game mode is on, keep it on after any config reload (wallpaper changes reload Hyprland).
do
    local f = io.open(home .. "/.cache/rice/gamemode", "r")
    if f then
        f:close()
        pcall(hl.config, {
            decoration = { blur = { enabled = false }, shadow = { enabled = false } },
            animations = { enabled = false },
        })
    end
end
