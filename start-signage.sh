#!/bin/sh

# Keep the display awake and launch a single full-screen Wayland kiosk.
setterm --blank 0 --powerdown 0 --powersave off 2>/dev/null || true

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

while true; do
  dbus-run-session -- cage -s -- chromium \
    --ozone-platform=wayland \
    --kiosk \
    --noerrdialogs \
    --no-first-run \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-background-networking \
    --disable-features=Translate \
    --remote-debugging-address=127.0.0.1 \
    --remote-debugging-port=9222 \
    --autoplay-policy=no-user-gesture-required \
    --password-store=basic \
    --user-data-dir=/home/admin/.config/chromium-signage \
    file:///home/admin/signage/current/index.html

  sleep 2
done
