#!/bin/sh

# Keep the display awake and launch a single full-screen Wayland kiosk.
setterm --blank 0 --powerdown 0 --powersave off 2>/dev/null || true

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# The Samsung display advertises 3840x2160 at 30 Hz as its preferred mode.
# Force 1080p at 60 Hz after every Cage start so Chromium renders one quarter
# as many pixels and the scrolling ticker is not limited to 30 fps.
SIGNAGE_OUTPUT=HDMI-A-1
SIGNAGE_MODE=1920x1080@60.000000Hz

force_display_mode() {
  attempt=0
  sleep 2
  while [ "$attempt" -lt 30 ]; do
    if wlr-randr --output "$SIGNAGE_OUTPUT" --mode "$SIGNAGE_MODE" \
      >/tmp/signage-display-mode.log 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  return 1
}

while true; do
  force_display_mode &
  display_mode_pid=$!

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

  wait "$display_mode_pid" 2>/dev/null || true

  sleep 2
done
