# Codex Handoff: Shallowford Pi Signage

Read this file first. Use `README.md` only when detailed operator instructions are needed. Do not reconstruct context from the full chat unless these files are insufficient.

## Objective and hardware

- Raspberry Pi 4 Model B, 2 GB RAM, Raspberry Pi OS Lite 64-bit (Debian Trixie).
- Host: `pisignageshallowford.local`; SSH user: `admin`.
- Display: Samsung HDMI display; its preferred mode is 3840x2160 at 30 Hz, so `start-signage.sh` forces HDMI-A-1 to 1920x1080 at 60 Hz after every Cage start.
- GitHub source: `https://github.com/thelocalpixel-star/shallowford-pi`, branch `main`.
- Never put passwords, Gmail App Passwords, or Wi-Fi credentials in this repository.

## Required behavior

- Play local content from 10:00 AM through 10:00 PM Eastern.
- Two display modes, tracked in `/etc/default/signage-mode`: `normal` (`index.html` + `ad.mp4`) and `takeover` (`takeover.html` + `takeover.png`, celebrate image by default).
- A custom takeover image shows for 30 minutes, then automatically reverts to the celebrate image (one-shot timer + per-minute `signage-takeover-watch` backstop).
- After every mode switch, trigger `signage-health-email.service` so the new screen is confirmed visually.
- Download GitHub content daily at 8:00 AM Eastern. The update refreshes files but never changes the active mode.
- Downloads are atomic: a failed download or validation must leave the active release unchanged.
- Playback must remain fully local and work without internet.
- A local heartbeat watchdog checks Chromium every minute and restarts the kiosk after two consecutive failures.
- Email an inline screenshot and concise health dashboard hourly at 10:05 AM through 9:05 PM.

## Architecture and paths on the Pi

- Active content symlink: `/home/admin/signage/current`
- Immutable releases: `/home/admin/signage/releases/<release-id>` — each holds `index.html` (active page), `ad.mp4`, plus `normal.html`, `takeover.html`, `takeover.png`
- Display mode flag: `/etc/default/signage-mode` (`MODE=normal|takeover`, optional `TAKEOVER_UNTIL` epoch)
- Pristine celebrate image: `/home/admin/signage/celebrate.png`
- Kiosk launcher: `/home/admin/start-signage.sh`
- Kiosk session: Cage + Chromium on `getty@tty1.service`
- Schedule config: `/etc/default/signage-schedule`
- Installed commands: `/usr/local/sbin/signage-*` (deploy, update, schedule, watchdog, `signage-display-mode`, `signage-takeover-watch`)
- Passwordless sudo for signage commands: `/etc/sudoers.d/signage`
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
3. Switch display modes with `sudo signage-display-mode normal|takeover [custom-png]`; after every switch run `sudo systemctl start signage-health-email.service`.
4. Deploy content with `sudo signage-deploy-files INDEX_HTML AD_MP4 SOURCE` (companions ride along automatically).
5. Install changed support scripts deliberately; the daily updater only activates content files.
6. Preserve Raspberry Pi Connect and SSH access.
7. After changes, verify the relevant timer/service, active release, Chromium heartbeat, `vcgencmd get_throttled`, and temperature.
8. Reboot-test changes that affect boot, scheduling, Cage, Chromium, or systemd.
9. Commit operational changes to the GitHub repository after successful verification.

## Quick checks

```bash
cat /etc/default/signage-mode
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
