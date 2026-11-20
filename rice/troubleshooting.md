# Troubleshooting notes
Fixes for problems already met on this setup. Open with Mod+Shift+N, or Super+I > Troubleshooting.
Copy a command: select it with the mouse, then paste in kitty with Ctrl+Shift+V.

## No sound / cava says "could not connect"
PipeWire (the sound system) is not running.
    systemctl --user enable --now pipewire pipewire-pulse wireplumber
    wpctl status
Under Audio > Sinks your speakers should have a * next to them.
Apps opened before the fix (Firefox, Spotify) must be fully closed and reopened.
Firefox missing from Super+I > Sound > Playback? Check pactl info shows "PulseAudio (on PipeWire)".

## Bluetooth: no sound, or it sounds like a phone call
The speaker is in headset mode. Super+I > Sound > Configuration tab:
set the speaker to "High Fidelity Playback (A2DP Sink)".
Better codecs (AAC, aptX, LDAC, SBC-XQ) appear in the same list if the speaker supports them.
Output Devices tab: click the green tick next to the speaker to make it the default.
wpctl numbers change on every reconnect, so use this app instead of old numbers.

## Bluetooth: turning on and auto-reconnect
    sudo systemctl enable --now bluetooth
    bluetoothctl list        (should show a Controller)
Pair in Super+I > Bluetooth. Right-click the device > Trust, so it reconnects by itself.

## Bluetooth: "br-connection-key-missing"
The speaker and this PC no longer share the same pairing key, usually because it was
paired again with Windows, a phone, or after a reset. Each OS on this PC pairs separately,
so pairing in Windows can break Linux's pairing (and the other way round).
Fix: in Super+I > Bluetooth, right-click the speaker > Remove. Put the speaker in pairing
mode, Search, Pair, Trust, Connect. Or in a terminal:
    bluetoothctl devices          (note the speaker's address)
    bluetoothctl remove <address>
    bluetoothctl scan on          (wait for it to appear, then Ctrl+C)
    bluetoothctl pair <address>
    bluetoothctl trust <address>
    bluetoothctl connect <address>

## Bluetooth volume jumps back to 100%
Usually fixed by disconnecting and reconnecting the speaker.
If it keeps happening, stop syncing volume with the speaker:
    mkdir -p ~/.config/wireplumber/wireplumber.conf.d
    printf 'monitor.bluez.properties = {\n  bluez5.hw-volume = [ ]\n}\n' > ~/.config/wireplumber/wireplumber.conf.d/51-bt-volume.conf
    systemctl --user restart wireplumber
Then keep the PC volume at 70-100% and use the speaker's buttons (quiet digital volume sounds thinner).
Undo: delete that file and restart wireplumber.

## Wi-Fi is off or will not connect
    nmcli radio wifi on
    nmtui                    (Activate a connection)
In nmcli device, ignore the "p2p" line; the wifi line is wlan0 or wlp...
State "unavailable" = switched off. No wifi line at all = card locked by Windows:
turn off Fast Startup in Windows (Control Panel > Power Options > Choose what the
power buttons do > untick Turn on fast startup), Shut down fully, boot Arch.

## Wi-Fi is slow or keeps dropping
Turn off Wi-Fi power saving:
    printf '[connection]\nwifi.powersave = 2\n' | sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf
    sudo systemctl restart NetworkManager
Prefer the 5 GHz network when close to the router: nmcli device wifi list
For big downloads, phone USB tethering always works (turn on USB tethering after plugging in).

## PC boots straight into Windows
This BIOS ignores Linux's boot order. Fixed once from Windows (admin Terminal, keep the quotes):
    bcdedit /set "{bootmgr}" path \EFI\GRUB\grubx64.efi
Undo:   bcdedit /set "{bootmgr}" path \EFI\Microsoft\Boot\bootmgfw.efi
Quick way in meanwhile: BIOS > Boot Override > GRUB.
Check Linux's own order with: sudo efibootmgr   (BootCurrent = what you booted this time)

## Windows missing from the GRUB menu
    sudo pacman -S --needed os-prober ntfs-3g
    sudo nano /etc/default/grub       (remove the # before GRUB_DISABLE_OS_PROBER=false)
    sudo grub-mkconfig -o /boot/grub/grub.cfg
Look for "Found Windows Boot Manager" in the output.

## Arch will not boot at all (rescue)
Boot the Ventoy USB (GRUB2 mode), then:
    lsblk                                  (check the partition numbers first)
    mount /dev/nvme0n1p5 /mnt
    mount /dev/nvme0n1p1 /mnt/boot/efi
    arch-chroot /mnt
Fix things from there, then: exit, umount -R /mnt, reboot.

## Text shows as square boxes
Fonts are missing:
    sudo pacman -S noto-fonts ttf-jetbrains-mono-nerd
Then restart Hyprland (Mod+M, log in, Hyprland).

## Hyprland frozen or odd after an update
Updating Hyprland while it runs can break the open session.
Ctrl+Alt+F2 (Fn+2 on the 60% keyboard), log in, then:
    sudo pkill Hyprland
Switch back with Ctrl+Alt+F1 and start Hyprland again.

## No notifications / bell missing from the bar
Only one notification app can run at a time. Stop the old one and start swaync:
    pkill mako; setsid -f swaync
Mod+N opens the notification centre. A crossed bell means Do Not Disturb is on
(right-click the bell, or it was left on by game mode).

## Game mode stuck on
Press Mod+G again, or reset it by hand:
    rm ~/.cache/rice/gamemode; hyprctl reload; swaync-client --dnd-off
Game mode always starts off after logging in.

## Login screen will not appear
Ctrl+Alt+F2, log in as text, then:
    ~/.config/rice/login-undo.sh
That puts booting back to text login + typing Hyprland.

## Super+R does nothing / "autogenerated config" banner
Run the installer again (cd ~/dotfiles && bash install.sh), or in ~/.config/hypr/hyprland.lua:
  set the menu line to:  local menu = os.getenv("HOME") .. "/.config/rice/launcher.sh"
  put -- in front of the line containing "autogenerated"
Use Tab to complete long paths so typos do not open an empty new file.

## Terminal keys on the 60% keyboard
~ (home folder): Shift+Esc or Fn+Shift+Esc. Or use $HOME instead.
Paste in kitty: Ctrl+Shift+V (plain Ctrl+V does not paste in terminals).
Middle-click pastes whatever text is highlighted.
Screenshots without a Print key: Mod+Shift+A (area), Mod+Shift+F (full).

## Wallpaper picker does not open
Mod+Shift+W needs the quickshell package (sudo pacman -S quickshell); without it you
get the older rofi strip instead. Errors are logged in:
    ~/.cache/rice/wallpicker.log

## fastfetch picture overlaps the text
The window is too narrow for a picture. The rice's fastfetch picks a smaller logo in
narrow windows by itself; if you still see overlap, make the window wider, or raise
MIN_COLS_IMAGE in ~/.config/rice/fetch.conf. Plain fastfetch: /usr/bin/fastfetch

## Blurry wallpaper
Saving from a search page grabs a small preview. Check real sizes:
    file ~/Pictures/Wallpapers/*
Anything smaller than the screen will look soft. Download from the wallpaper's own page.
Folder names are case sensitive: Wallpapers, not wallpapers.

## Terminal not see-through / too frosted
Transparency: TERMINAL_ALPHA in ~/.config/rice/theme-sync.py (0 = invisible, 1 = solid,
e.g. 0.35), then pick a wallpaper again and open a new kitty.
Frosting: blur size and passes in ~/.config/hypr/rice.lua, then hyprctl reload.

## Bar missing or a change not showing
    pkill waybar; setsid -f waybar
    hyprctl reload
    hyprctl configerrors

## Update the rice from GitHub
    cd ~/dotfiles && git pull && bash install.sh
Your weather location and wallpapers are kept. Old configs are backed up in ~/.config/rice-backup.
