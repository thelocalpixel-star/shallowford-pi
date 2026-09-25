# Shallowford Raspberry Pi Digital Signage

This Raspberry Pi displays `index.html` and loops `ad.mp4` on a 1920×1080 screen. It uses Raspberry Pi OS Lite, Cage (a minimal Wayland kiosk), and Chromium. There is no full desktop environment.

## Normal operation

- The display plays every day from **10:00 AM until 10:00 PM Eastern time**.
- At **8:00 AM**, the Pi downloads the `main` branch of this repository.
- `index.html` and `ad.mp4` must remain in the repository root and keep those exact names.
- An update is validated and installed as a new release before it becomes active.
- If GitHub, Wi-Fi, DNS, or the download is unavailable, the update fails safely and the Pi continues using the last working release.
- The Pi checks its playback schedule at boot and once per minute, so power can be removed and restored without manual intervention.
- A local watchdog checks a live page-and-video heartbeat every minute. After two consecutive failed checks it restarts Chromium automatically.
- Playback does not require internet access. The HTML, MP4, browser, schedule, and watchdog are stored and run locally.
- Raspberry Pi Connect remote shell remains available for maintenance.
- A screenshot and health report can be emailed hourly while signage is playing.

The Pi uses the `America/New_York` time zone, which automatically handles Eastern Standard Time and Eastern Daylight Time.

## Offline playback and automatic recovery

The signage loads from `file:///home/admin/signage/current/index.html`, and the video is stored beside it on the SD card. Wi-Fi or internet loss therefore does not stop playback. The 10:00 AM start and 10:00 PM stop are controlled by the Pi's synchronized local clock and continue without an active internet connection.

The GitHub updater downloads into a temporary directory. If internet access is unavailable at 8:00 AM, it exits without changing `/home/admin/signage/current`, so the last working ad continues to play. Email delivery failures are also independent of the kiosk.

During playback hours, `signage-watchdog.timer` checks a JavaScript heartbeat exposed only on the Pi's loopback interface. This confirms that Chromium, the page, and video playback are responsive. One failed check is tolerated; two consecutive failures cause the kiosk to restart automatically.

Check the watchdog:

```bash
systemctl status signage-watchdog.timer --no-pager
journalctl -u signage-watchdog.service -n 30 --no-pager
```

## Hourly screenshot and health email

The Pi is configured to send an email from and to `thelocalpixel@gmail.com` at 5 minutes past every hour from **10:05 AM through 9:05 PM**. This produces 12 reports per day while playback is active and avoids racing the 10:00 AM startup or 10:00 PM shutdown.

Each message uses a compact HTML dashboard with a real 1920×1080 screenshot displayed directly inside the email. It includes:

- Overall health status
- Temperature and power/thermal throttling status
- Kiosk process status
- Uptime, load, and CPU snapshot
- Memory and storage usage
- IP address and Wi-Fi signal information
- Active content release and checksums
- Last automatic-update log entry
- Current playback schedule

Screenshots are retained on the Pi for three days in `/home/admin/signage/screenshots` and then removed automatically.

### One-time Gmail authorization

Gmail requires an App Password; the normal Google account password will not work. Enable 2-Step Verification on the Google account, open [Google App Passwords](https://myaccount.google.com/apppasswords), and create an app password for the signage Pi.

Then connect to the Pi and run:

```bash
sudo signage-email-configure
```

Paste the 16-character App Password at the hidden prompt. Spaces are accepted and removed automatically. The secret is stored only on the Pi in `/etc/signage-email/app-password`, readable only by root. It is never stored in this repository.

The configuration command immediately sends a test screenshot and health report. Check Gmail's Sent folder and Inbox. If the message is not visible, also check Spam.

Check the email schedule and delivery logs:

```bash
systemctl list-timers signage-health-email.timer --no-pager
journalctl -u signage-health-email.service -n 50 --no-pager
```

Send a report immediately:

```bash
sudo systemctl start signage-health-email.service
```

Disable or re-enable hourly reports:

```bash
sudo systemctl disable --now signage-health-email.timer
sudo systemctl enable --now signage-health-email.timer
```

To replace the Gmail App Password, rerun `sudo signage-email-configure`.

## Publishing new content through GitHub

1. Prepare an H.264 MP4 named `ad.mp4`. For best Raspberry Pi 4 performance, use 1920×1080 or smaller, 30 fps, H.264, and AAC audio if audio is required.
2. Update `index.html` if the layout or ticker needs to change.
3. Upload both files to the `main` branch of this repository.
4. The Pi downloads them automatically at 8:00 AM Eastern time the next day.
5. To install the GitHub version immediately, connect to the Pi and run:

   ```bash
   sudo systemctl start signage-update.service
   ```

6. Check the result:

   ```bash
   systemctl status signage-update.service --no-pager
   journalctl -u signage-update.service -n 50 --no-pager
   ```

Do not remove the current files from the Pi before an update. The updater intentionally downloads into a temporary directory and switches releases only after both files pass validation.

## Manually installing content without GitHub

From a Mac or Linux computer on the same network, copy a replacement video to the Pi:

```bash
scp ad.mp4 admin@pisignageshallowford.local:/home/admin/new-ad.mp4
```

Then connect to the Pi:

```bash
ssh admin@pisignageshallowford.local
```

Install only the new video while retaining the currently active HTML:

```bash
sudo /usr/local/sbin/signage-deploy-files \
  /home/admin/signage/current/index.html \
  /home/admin/new-ad.mp4 \
  manual-video
```

To replace both files, copy both to the Pi and run:

```bash
sudo /usr/local/sbin/signage-deploy-files \
  /home/admin/new-index.html \
  /home/admin/new-ad.mp4 \
  manual-files
```

The deployment is atomic and automatically restarts the kiosk if it is currently inside playback hours. The next successful scheduled GitHub update will replace a manual release if the GitHub files are different.

## Changing playback hours

Edit the schedule on the Pi:

```bash
sudo nano /etc/default/signage-schedule
```

The default configuration is:

```text
START_TIME=10:00
STOP_TIME=22:00
```

Use 24-hour `HH:MM` values. Overnight schedules are supported; for example, `START_TIME=18:00` and `STOP_TIME=02:00`.

Apply the change immediately:

```bash
sudo systemctl start signage-schedule.service
```

Check the saved configuration and the next schedule check:

```bash
cat /etc/default/signage-schedule
systemctl list-timers signage-schedule.timer --no-pager
```

## Changing the daily download time

Create an override for the download timer:

```bash
sudo systemctl edit signage-update.timer
```

Enter the following, changing `08:00:00` as needed:

```ini
[Timer]
OnCalendar=
OnCalendar=*-*-* 08:00:00
```

Then reload and restart the timer:

```bash
sudo systemctl daemon-reload
sudo systemctl restart signage-update.timer
systemctl list-timers signage-update.timer --no-pager
```

## Updating Wi-Fi

Changing Wi-Fi remotely can disconnect the current session. Keep the old network available until the new connection is verified, or connect a keyboard and monitor to the Pi.

List Wi-Fi networks and saved connections:

```bash
nmcli device wifi list
nmcli connection show
```

Connect to a new network:

```bash
sudo nmcli device wifi connect "WIFI_NAME" password "WIFI_PASSWORD" ifname wlan0
```

Verify the active connection and IP address:

```bash
nmcli connection show --active
hostname -I
```

To change the password for an already saved network:

```bash
sudo nmcli connection modify "WIFI_NAME" wifi-sec.psk "NEW_WIFI_PASSWORD"
sudo nmcli connection up "WIFI_NAME"
```

Do not store Wi-Fi passwords in this repository or in `README.md`.

## Time zone and clock

Check time synchronization:

```bash
timedatectl
```

Set Eastern time again if needed:

```bash
sudo timedatectl set-timezone America/New_York
sudo timedatectl set-ntp true
```

To use another location, list available zones with `timedatectl list-timezones`, set the desired zone, and then rerun the schedule service.

## Useful maintenance commands

Check whether the kiosk is running:

```bash
systemctl is-active getty@tty1.service
pgrep -af 'cage|chromium'
```

See the active release and all retained releases:

```bash
readlink -f /home/admin/signage/current
ls -lh /home/admin/signage/releases
cat /home/admin/signage/current/release-info.txt
```

Run an immediate download:

```bash
sudo systemctl start signage-update.service
```

Restart playback during scheduled hours:

```bash
sudo systemctl restart getty@tty1.service
```

Check system health:

```bash
vcgencmd get_throttled
vcgencmd measure_temp
free -h
df -h /
```

`throttled=0x0` means the Pi has not detected power or temperature throttling.

Reboot safely:

```bash
sudo reboot
```

## Roll back to an earlier release

List release IDs:

```bash
ls -1 /home/admin/signage/releases
```

Activate one of them by replacing `RELEASE_ID` below:

```bash
sudo /usr/local/sbin/signage-deploy-files \
  /home/admin/signage/releases/RELEASE_ID/index.html \
  /home/admin/signage/releases/RELEASE_ID/ad.mp4 \
  rollback
```

## Installed paths

| Purpose | Path |
| --- | --- |
| Active content | `/home/admin/signage/current/` |
| Retained releases | `/home/admin/signage/releases/` |
| Kiosk launcher | `/home/admin/start-signage.sh` |
| Playback schedule | `/etc/default/signage-schedule` |
| GitHub updater | `/usr/local/sbin/signage-update` |
| Atomic deployment tool | `/usr/local/sbin/signage-deploy-files` |
| Playback scheduler | `/usr/local/sbin/signage-schedule` |
| Systemd units | `/etc/systemd/system/signage-*.service` and `.timer` |

The automatic updater downloads only `index.html` and `ad.mp4` from the repository. Changes to the setup scripts themselves must be installed deliberately.
