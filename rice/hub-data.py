#!/usr/bin/env python3
"""hub-data.py: one JSON line with everything the control centre shows.

Run by hub.qml every 2 seconds, only while the control centre is open, so it
costs nothing the rest of the time. Read-only: it never changes a setting.
Each value is read from the kernel (/sys, /proc) or a local tool; nothing is
sent over the network (weather comes from the bar's cache file).
"""

import glob
import json
import os
import subprocess

HOME = os.path.expanduser("~")
CACHE = os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")) + "/rice"
RICE = os.path.join(HOME, ".config/rice")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")


def run(*cmd, timeout=2):
    """Output of a command, or "" if it is missing, fails or hangs."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except Exception:
        return default


def network():
    wifi_on = run("nmcli", "-t", "-f", "WIFI", "general") == "enabled"
    ssid, signal, wired = "", 0, False
    for line in run("nmcli", "-t", "-f", "TYPE,STATE", "device").splitlines():
        kind, _, state = line.partition(":")
        if kind == "ethernet" and state == "connected":
            wired = True
    for line in run("nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "device", "wifi", "list", "--rescan", "no").splitlines():
        parts = line.split(":", 2)
        if len(parts) == 3 and parts[0] == "yes":
            signal = int(parts[1] or 0)
            ssid = parts[2].replace("\\:", ":")
            break
    return {"wifiOn": wifi_on, "ssid": ssid, "signal": signal, "wired": wired}


def bluetooth():
    show = run("bluetoothctl", "show")
    if not show or "No default controller" in show:
        return {"present": False, "on": False, "device": ""}
    on = "Powered: yes" in show
    device = ""
    if on:
        for line in run("bluetoothctl", "devices", "Connected").splitlines():
            parts = line.split(" ", 2)
            if len(parts) == 3 and parts[0] == "Device":
                device = parts[2]
                break
    return {"present": True, "on": on, "device": device}


def volume():
    out = run("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")   # "Volume: 0.76 [MUTED]"
    try:
        level = round(float(out.split()[1]) * 100)
    except Exception:
        level = 0
    return {"level": level, "muted": "MUTED" in out}


def brightness():
    # Laptop screens only; most desktop monitors cannot be dimmed this way.
    out = run("brightnessctl", "-m", "-c", "backlight", "info")  # name,class,cur,pct%,max
    parts = out.split(",")
    if len(parts) >= 4 and parts[3].endswith("%"):
        return int(parts[3][:-1])
    return -1


def battery():
    for bat in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        cap = read(bat + "/capacity")
        if not cap.isdigit():
            continue
        status = read(bat + "/status", "Unknown")
        return {"present": True, "level": int(cap), "status": status, "time": battery_time(bat, status)}
    return {"present": False, "level": 0, "status": "", "time": ""}


def battery_time(bat, status):
    def num(name):
        v = read(bat + "/" + name)
        return int(v) if v.lstrip("-").isdigit() else 0
    now, full, rate = num("energy_now"), num("energy_full"), num("power_now")
    if not now:                                   # some batteries report charge instead of energy
        now, full, rate = num("charge_now"), num("charge_full"), num("current_now")
    if rate <= 0:
        return ""
    hours = (now / rate) if status == "Discharging" else ((full - now) / rate) if status == "Charging" else 0
    if hours <= 0:
        return ""
    h, m = int(hours), int(round((hours - int(hours)) * 60))
    when = "left" if status == "Discharging" else "to full"
    return f"{h}h {m:02d}m {when}" if h else f"{m} min {when}"


def cpu():
    # Usage since the last call (2 s ago), from /proc/stat.
    fields = [int(x) for x in read("/proc/stat").splitlines()[0].split()[1:]]
    idle, total = fields[3] + fields[4], sum(fields)
    state = os.path.join(RUNTIME, "rice-hub-cpu")
    prev = read(state).split()
    with open(state, "w") as f:
        f.write(f"{idle} {total}")
    if len(prev) == 2:
        d_idle, d_total = idle - int(prev[0]), total - int(prev[1])
        if d_total > 0:
            return round(100 * (1 - d_idle / d_total))
    return -1


def gpu():
    for dev in glob.glob("/sys/class/drm/card*/device/gpu_busy_percent"):   # AMD only
        v = read(dev)
        if v.isdigit():
            return int(v)
    return -1


def ram():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        info[key] = int(rest.split()[0]) if rest.split() else 0
    total = info.get("MemTotal", 0)
    return round(100 * (1 - info.get("MemAvailable", 0) / total)) if total else -1


def media():
    status = run("playerctl", "status")
    if status not in ("Playing", "Paused"):
        return {"active": False, "playing": False, "title": "", "artist": ""}
    meta = run("playerctl", "metadata", "--format", "{{title}}\t{{artist}}").split("\t")
    return {"active": True, "playing": status == "Playing",
            "title": meta[0] if meta else "", "artist": meta[1] if len(meta) > 1 else ""}


def idle():
    conf = {"enabled": "0", "lock": "10", "sleep": "0"}
    for line in read(os.path.join(RICE, "idle.conf")).splitlines():
        key, _, value = line.partition("=")
        if key.strip() in conf:
            conf[key.strip()] = value.strip().strip('"')
    return {"enabled": conf["enabled"] == "1",
            "lock": int(conf["lock"]) if conf["lock"].isdigit() else 10,
            "sleep": int(conf["sleep"]) if conf["sleep"].isdigit() else 0}


def weather():
    try:
        data = json.loads(read(os.path.join(CACHE, "weather.json"), "{}"))
        return data.get("text", "")
    except Exception:
        return ""


print(json.dumps({
    "net": network(),
    "bt": bluetooth(),
    "dnd": run("swaync-client", "-D") == "true",
    "vol": volume(),
    "bright": brightness(),
    "bat": battery(),
    "cpu": cpu(),
    "gpu": gpu(),
    "ram": ram(),
    "media": media(),
    "idle": idle(),
    "weather": weather(),
    "gamemode": os.path.exists(os.path.join(CACHE, "gamemode")),
}))
