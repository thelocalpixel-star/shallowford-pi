#!/bin/sh

# Keep the display awake and launch a single full-screen Wayland kiosk.
setterm --blank 0 --powerdown 0 --powersave off 2>/dev/null || true

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# The Samsung display advertises 3840x2160 at 30 Hz as its preferred mode.
# Force 1080p at 60 Hz after every Cage start so Chromium renders one quarter
# as many pixels and the scrolling ticker is not limited to 30 fps.
SIGNAGE_OUTPUT=HDMI-A-1
SIGNAGE_MODE=1920x1080@60.000000Hz

while true; do
  # Run the mode setter as Cage's child so it inherits the exact Wayland
  # socket for this compositor session. Keep checking after Chromium starts:
  # a TV power cycle is an HDMI hotplug event and can restore its preferred 4K
  # mode. Chromium is never launched until 1080p/60 is confirmed as current.
  dbus-run-session -- cage -s -- sh -c '
    output=$1
    mode=$2

    mode_is_active() {
      wlr-randr 2>/dev/null | grep -Eq \
        "^[[:space:]]+1920x1080 px, 60(\\.0+)? Hz \\([^)]*current[^)]*\\)$"
    }

    apply_mode() {
      wlr-randr --output "$output" --mode "$mode" \
        >>/tmp/signage-display-mode.log 2>&1 || true
    }

    : >/tmp/signage-display-mode.log
    while ! mode_is_active; do
      apply_mode
      sleep 1
    done

    chromium \
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
      file:///home/admin/signage/current/index.html &
    chromium_pid=$!

    while kill -0 "$chromium_pid" 2>/dev/null; do
      sleep 5
      if ! mode_is_active; then
        printf "Display mode changed; restoring %s on %s\n" \
          "$mode" "$output" >>/tmp/signage-display-mode.log
        apply_mode
      fi
    done

    wait "$chromium_pid"
  ' signage-mode "$SIGNAGE_OUTPUT" "$SIGNAGE_MODE"

  sleep 2
done
