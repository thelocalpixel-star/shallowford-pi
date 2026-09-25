# Codex Handoff: Shallowford Pi Signage

Read this file first. Use `README.md` only when detailed operator instructions are needed. Do not reconstruct context from the full chat unless these files are insufficient.

## Objective and hardware

- Raspberry Pi 4 Model B, 2 GB RAM, Raspberry Pi OS Lite 64-bit (Debian Trixie).
- Host: `pisignageshallowford.local`; SSH user: `admin`.
- Display: Dell S2421HN at 1920x1080, 60 Hz.
- GitHub source: `https://github.com/thelocalpixel-star/shallowford-pi`, branch `main`.
- Never put passwords, Gmail App Passwords, or Wi-Fi credentials in this repository.

## Required behavior

- Play local `index.html` plus `ad.mp4` from 10:00 AM through 10:00 PM Eastern.
- Download GitHub content daily at 8:00 AM Eastern.
- Downloads are atomic: a failed download or validation must leave the active release unchanged.
- Playback must remain fully local and work without internet.
- A local heartbeat watchdog checks Chromium every minute and restarts the kiosk after two consecutive failures.
- Email an inline screenshot and concise health dashboard hourly at 10:05 AM through 9:05 PM.

## Architecture and paths on the Pi

- Active content symlink: `/home/admin/signage/current`
- Immutable releases: `/home/admin/signage/releases/<release-id>`
- Kiosk launcher: `/home/admin/start-signage.sh`
- Kiosk session: Cage + Chromium on `getty@tty1.service`
- Schedule config: `/etc/default/signage-schedule`
- Installed commands: `/usr/local/sbin/signage-*`
- Units: `/etc/systemd/system/signage-*.service` and `signage-*.timer`
- Logs: `journalctl -u <unit>`; kiosk log: `/home/admin/signage-kiosk.log`
- Chromium heartbeat endpoint: loopback only, `http://127.0.0.1:9222/json/list`

## Services and timers

- `signage-update.timer`: GitHub download at 08:00.
- `signage-schedule.timer`: applies playback hours every minute.
- `signage-watchdog.timer`: checks live page/video heartbeat every minute.
- `signage-health-email.timer`: reports hourly during playback.
- `getty@tty1.service`: owns the local autologin kiosk session; restarting it restarts Cage/Chromium.

## Safe workflow

1. Edit and validate files locally. Use `apply_patch` for text edits.
2. Never overwrite `/home/admin/signage/current` directly.
3. Deploy content with `sudo signage-deploy-files INDEX_HTML AD_MP4 SOURCE`.
4. Install changed support scripts deliberately; the daily updater only activates `index.html` and `ad.mp4`.
5. Preserve Raspberry Pi Connect and SSH access.
6. After changes, verify the relevant timer/service, active release, Chromium heartbeat, `vcgencmd get_throttled`, and temperature.
7. Reboot-test changes that affect boot, scheduling, Cage, Chromium, or systemd.
8. Commit operational changes to the GitHub repository after successful verification.

## Quick checks

```bash
pgrep -af 'cage|chromium.*signage/current/index.html'
sudo signage-watchdog
readlink -f /home/admin/signage/current
systemctl list-timers 'signage-*' --no-pager
vcgencmd get_throttled
vcgencmd measure_temp
rpi-connect status
```

## Constraints and known limitation

- Do not install a desktop environment or make playback depend on a remote website.
- Do not add risky Chromium flags such as `--enable-zero-copy`; the current Wayland/V3D configuration is verified smooth.
- Avoid restarting the kiosk when downloaded content is unchanged.
- Keep secrets root-only on the Pi, never in Git or chat output.
- Pi 4 has no hardware RTC. Playback continues through internet loss while powered, but exact scheduling after a prolonged offline power outage requires an RTC module.
