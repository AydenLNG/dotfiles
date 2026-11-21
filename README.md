# dotfiles

A Hyprland rice for Arch Linux: frosted-glass terminals and a glass bar, with colours
that follow the wallpaper. Pick a wallpaper from a centred carousel and it swaps in with an
animated transition, then the terminal, bar, launcher, notifications, file manager,
settings apps, lock screen, login screen and window borders all recolour to match.

## Features

- **Glass look:** translucent kitty terminals and waybar, blurred by Hyprland
- **Wallpaper picker:** one centred row of `~/Pictures/Wallpapers` (Quickshell); every wallpaper is a tall, thin slice and the selected one opens up into a wide card in the middle. Space previews it behind, Enter applies with an animated transition (awww), Esc puts the old one back. Falls back to a rofi strip if Quickshell is missing
- **App launcher:** rofi grid of app icons with Apps / Windows / Run tabs, in the same glass style; every menu uses rofi
- **Notification centre:** swaync popups plus a panel with history, Do Not Disturb and media controls (bell in the bar)
- **Game mode:** one key turns off blur, shadows and animations and silences notifications
- **Colour sync:** `theme-sync.py` reads the wallpaper's colours and recolours every app; open terminals and GTK apps update instantly
- **Settings menu:** one menu for sound, Wi-Fi, Bluetooth, display, appearance, weather, lock and login screen, keybinds and system updates
- **Bar:** three glass islands. Left: workspaces (and a game mode badge). Centre: clock with a calendar on hover, and the song title with buttons on hover. Right: volume with a slider on hover, network, internet ping (router ping on hover), a chart icon whose drawer holds CPU, GPU, RAM, weather and the tray, notifications, wallpaper and power
- **Weather:** for a place you type in `~/.config/rice/weather.conf`; your location is never detected automatically
- **Screenshots and clipboard history,** lock screen (hyprlock), cava visualizer
- **Login screen (optional):** greetd + ReGreet with your current wallpaper and colours, set up and removed with one script each
- **Plain and readable:** official Arch packages only, no AUR, no binaries, no location tracking

## Keybinds

| Keys | Action |
|---|---|
| `Mod + R` | App launcher (Apps / Windows / Run) |
| `Mod + I` | Settings menu |
| `Mod + N` | Notification centre |
| `Mod + G` | Game mode on / off |
| `Mod + Ctrl + Alt + Delete` | Restart straight into Windows once (asks for your password; the next restart is Arch again) |
| `Alt + Tab` / `Alt + Shift + Tab` | Next / previous workspace (1 to 5, wraps around, empty ones included) |
| `Mod + Shift + W` | Wallpaper picker: A / D or arrows move, Space previews, Enter applies, Esc cancels |
| `Mod + Shift + V` | Clipboard history |
| `Mod + Escape` | Power menu |
| `Print` | Screenshot of an area (saved to `~/Pictures/Screenshots` and copied) |
| `Shift + Print` | Screenshot of the whole screen |
| `Mod + /` | Keybind cheat sheet |
| `Mod + Shift + N` | Troubleshooting notes (fixes for common problems) |
| `Mod + Shift + A` / `Mod + Shift + F` | Same screenshots, for keyboards without a Print key |

`Mod` is Super by default. On a keyboard without a Windows key, set `local mod = "ALT"` at the
top of `hypr/rice.lua`. `Mod + W` is intentionally left free. Your own keybinds (terminal,
close window, file manager, ...) stay in your `hyprland.lua`. The full list is in the
settings menu under Keybinds.

## Apps it installs

| Group | Apps |
|---|---|
| Core | hyprland, kitty, waybar, rofi, quickshell, papirus-icon-theme, swaync, awww, imagemagick, python, playerctl, curl, fonts, adw-gtk-theme |
| File manager | thunar, gvfs, tumbler, ffmpegthumbnailer, file-roller, thunar-archive-plugin |
| Settings | pavucontrol, network-manager-applet, blueman, nwg-look, nwg-displays |
| Everyday | firefox, imv, mpv |
| Utilities | grim, slurp, wl-clipboard, cliphist, hyprlock |
| Terminal widgets | cava, fastfetch, btop, cmatrix |

Full list with notes: `packages.txt`.

## Install

Requires Arch Linux with Hyprland already started at least once (so `~/.config/hypr/hyprland.lua` exists).

```bash
git clone https://github.com/AydenLNG/dotfiles.git
cd dotfiles
bash install.sh
```

The installer asks before installing packages, backs up everything it replaces to
`~/.config/rice-backup/<date>/`, and copies files (no symlinks). Read it first, it is short.

Then add images to `~/Pictures/Wallpapers`, log out and back in, and press `Mod + Shift + W`.

## What follows the wallpaper

| App | How |
|---|---|
| kitty, waybar, rofi launcher / menus / picker, swaync, cava | colour files rewritten and reloaded |
| Window borders | `hypr/colors.lua`, then `hyprctl reload` |
| Thunar, Sound, Bluetooth, Network, nwg apps, File Roller | GTK named colours in `gtk-3.0/colors.css` and `gtk-4.0/colors.css` (needs the adw-gtk3-dark theme) |
| Lock screen | `hypr/hyprlock.conf` uses the wallpaper, blurred |
| Login screen | `/usr/local/share/rice-login` (only if set up) |
| imv | background colour |

Firefox follows dark mode but not the wallpaper colours. Changing the GTK theme in nwg-look
can switch away from adw-gtk3-dark, which stops GTK apps from following the wallpaper.

## Layout

```
hypr/rice.lua           autostart, glass blur, borders, animations, keybinds, float rules
hypr/colors.lua         border colours            (generated)
hypr/hyprlock.conf      lock screen               (generated)
waybar/                 bar modules, style, colours
kitty/                  terminal font, padding, colours; auto_font.py scales text with window width
fastfetch/              fastfetch modules and look
rice/fetch.sh           "fastfetch": logo and number of lines chosen to fit the window (random mix of ~/Pictures/Fetch pictures and text logos when there is room)
rice/fetch.conf         picture chance and which text logos (never overwritten on reinstall)
rice/ping.sh            bar ping: internet (1.1.1.1) and router
rice/media-status.sh    play / pause button in the media drawer
rice/workspace-cycle.sh Alt + Tab workspace cycling
rice/reboot-windows.sh  restart into Windows once (grub-reboot); one-time GRUB setup with your OK
swaync/config.json      notification centre layout
swaync/style.css        notification colours      (generated)
cava/config             audio visualizer
imv/config              image viewer              (generated)
gtk-3.0/, gtk-4.0/      GTK theme settings + colours
rice/theme-sync.py      wallpaper -> colour palette -> all apps
rice/wallpaper.sh       picker / random / restore
rice/wallpicker.qml     the centred picker (Quickshell); card sizes at the top
rice/launcher.sh        Mod + R app launcher (rice/launcher.rasi)
rice/menu.rasi          shared look of the small menus
rice/clipboard.sh       Mod + Shift + V clipboard history
rice/gamemode.sh        Mod + G game mode (rice/gamemode-status.sh for the bar)
rice/settings-menu.sh   Mod + I menu
rice/keybinds.sh        keybind cheat sheet
rice/screenshot.sh      area / full screenshots
rice/help.sh            troubleshooting viewer; notes in rice/troubleshooting.md
rice/gpu.sh             AMD GPU usage for the bar
rice/power-menu.sh      lock / logout / suspend / reboot / shutdown
rice/weather.sh         weather for the bar (uses wttr.in)
rice/weather.conf       your weather location (never overwritten on reinstall)
rice/login-setup.sh     optional login screen (system change, uses sudo)
rice/login-undo.sh      back to the text login
```

"Generated" files are rewritten every time the wallpaper changes. To change their layout
for good, edit the matching template in `rice/theme-sync.py`.

## Tweaking

| Want | Where |
|---|---|
| More or less glass on terminals | `TERMINAL_ALPHA` in `rice/theme-sync.py` |
| Stronger or softer blur | `blur.size` / `blur.passes` in `hypr/rice.lua` |
| Gaps and corner rounding | `gaps_in`, `gaps_out`, `rounding` in `hypr/rice.lua` |
| Transition styles and speed | `TRANSITIONS`, `DURATION` in `rice/wallpaper.sh` |
| Picker slice and card sizes | `sliceW`, `sliceH`, `selW`, `selH`, `gap` at the top of `rice/wallpicker.qml` |
| Weather location or units | `LOCATION` / `UNITS` in `~/.config/rice/weather.conf` |
| Font sizes | `font_size` in `kitty/kitty.conf`, `font-size` in `waybar/style.css`, `{FONT}` lines in `rice/theme-sync.py` |
| Back to the default palette | `~/.config/rice/theme-sync.py --default` |

## Login screen (optional)

`~/.config/rice/login-setup.sh` installs greetd, ReGreet and cage from the official repos,
writes `/etc/greetd/config.toml` and `/etc/greetd/regreet.toml` (backing up the originals), and
enables greetd for the next boot. The login wallpaper and colours live in
`/usr/local/share/rice-login`, owned by you, so they follow every wallpaper change without sudo.

If the login screen fails, press `Ctrl+Alt+F2`, log in, and run `~/.config/rice/login-undo.sh`.

## Notes

- In a VM, blur and transitions can be slow or choppy because of limited GPU support.
- nwg-displays saves monitor settings to `monitors.conf`, which a Lua Hyprland config does not read. Copy the setting into an `hl.monitor()` line in `hyprland.lua` to keep it.
- If colours do not update, check `~/.cache/rice/theme-sync.log`.
- Weather requests go to wttr.in with only the place name you set. Like any website, wttr.in can see the IP address the request comes from.

## Credits

- Look inspired by the "late night" rice by [1amSimp1e](https://github.com/1amSimp1e/dots). The default fallback palette in `rice/theme-sync.py` uses the colour values from that rice's kitty theme. No code was copied.
- Wallpaper transition idea, the GTK reload trick, and the structure of the Hyprland Lua config (bind wrapper, separate `colors.lua`), from [43PR/dotfiles](https://github.com/43PR/dotfiles) (MIT). The centred picker layout is also inspired by theirs; `rice/wallpicker.qml` is a separate, much smaller implementation written for this rice.

## License

MIT
