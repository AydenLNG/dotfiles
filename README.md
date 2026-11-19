# dotfiles

A Hyprland rice for Arch Linux: frosted-glass terminals and a glass bar, with colours
that follow the wallpaper. Pick a wallpaper from a preview grid and it swaps in with an
animated transition, then the terminal, bar, launcher, notifications, file manager,
settings apps, lock screen, login screen and window borders all recolour to match.

## Features

- **Glass look:** translucent foot terminals and waybar, blurred by Hyprland
- **Wallpaper picker with previews:** thumbnail grid of `~/Pictures/Wallpapers` (rofi), animated transitions via awww
- **Colour sync:** `theme-sync.py` reads the wallpaper's colours and recolours every app; open terminals and GTK apps update instantly
- **Settings menu:** one menu for sound, Wi-Fi, Bluetooth, display, appearance, weather, lock and login screen, keybinds and system updates
- **Bar:** workspaces, window title, clock, media, weather, volume, network, CPU, memory, tray, wallpaper and power buttons
- **Weather:** for a place you type in `~/.config/rice/weather.conf`; your location is never detected automatically
- **Screenshots and clipboard history,** lock screen (hyprlock), cava visualizer
- **Login screen (optional):** greetd + ReGreet with your current wallpaper and colours, set up and removed with one script each
- **Plain and readable:** official Arch packages only, no AUR, no binaries, no location tracking

## Keybinds

| Keys | Action |
|---|---|
| `Mod + I` | Settings menu |
| `Mod + Shift + W` | Wallpaper picker with previews (press again to close) |
| `Mod + Shift + V` | Clipboard history |
| `Mod + Escape` | Power menu |
| `Print` | Screenshot of an area (saved to `~/Pictures/Screenshots` and copied) |
| `Shift + Print` | Screenshot of the whole screen |

`Mod` is Super by default. On a keyboard without a Windows key, set `local mod = "ALT"` at the
top of `hypr/rice.lua`. `Mod + W` is intentionally left free. Your own keybinds (terminal,
close window, file manager, ...) stay in your `hyprland.lua`. The full list is in the
settings menu under Keybinds.

## Apps it installs

| Group | Apps |
|---|---|
| Core | hyprland, foot, waybar, fuzzel, rofi, mako, awww, imagemagick, python, playerctl, curl, fonts, adw-gtk-theme |
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
| foot, waybar, fuzzel, mako, rofi picker, cava | colour files rewritten and reloaded |
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
foot/                   terminal font, padding, colours
fuzzel/fuzzel.ini       launcher                  (generated)
mako/config             notifications             (generated)
cava/config             audio visualizer
imv/config              image viewer              (generated)
gtk-3.0/, gtk-4.0/      GTK theme settings + colours
rice/theme-sync.py      wallpaper -> colour palette -> all apps
rice/wallpaper.sh       picker / random / restore
rice/settings-menu.sh   Mod + I menu
rice/keybinds.sh        keybind cheat sheet
rice/screenshot.sh      area / full screenshots
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
| Weather location or units | `LOCATION` / `UNITS` in `~/.config/rice/weather.conf` |
| Font sizes | `size=` in `foot/foot.ini`, `font-size` in `waybar/style.css`, `{FONT}` lines in `rice/theme-sync.py` |
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
- Wallpaper transition idea, the GTK reload trick, and the structure of the Hyprland Lua config (bind wrapper, separate `colors.lua`), from [43PR/dotfiles](https://github.com/43PR/dotfiles) (MIT). The wallpaper picker is a separate implementation using rofi instead of Quickshell.

## License

MIT
