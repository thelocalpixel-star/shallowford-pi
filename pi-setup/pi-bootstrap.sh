#!/bin/sh
# pi-bootstrap.sh — one-shot installer for the signage display-mode architecture.
#
# Run ON THE PI as the admin user:
#   curl -sSL -o /tmp/pi-bootstrap.sh \
#     https://raw.githubusercontent.com/thelocalpixel-star/shallowford-pi/main/pi-setup/pi-bootstrap.sh \
#   && sudo bash /tmp/pi-bootstrap.sh
#
# Installs the mode-aware scripts, the takeover revert watchdog timer,
# passwordless sudo for signage commands, sets the standing Celebrate
# takeover, runs a mode-aware update, tests a normal -> takeover flip,
# prunes old releases, and triggers the health email. Ends with Celebrate live.
set -eu

REPO=thelocalpixel-star/shallowford-pi
RAW="https://raw.githubusercontent.com/$REPO/main"
SIGNAGE_ROOT=/home/admin/signage

say() { printf '\n==> %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run with sudo: sudo bash /tmp/pi-bootstrap.sh"

fetch() { # url dest mode
  curl --fail --silent --show-error --location \
    --connect-timeout 20 --max-time 300 --retry 3 --retry-delay 5 \
    --output "$2" "$1"
  chmod "$3" "$2"
}

say "Baseline"
date
uptime
df -h / | tail -1
free -m | head -2
vcgencmd measure_temp 2>/dev/null || true
vcgencmd get_throttled 2>/dev/null || true

say "Installing signage scripts to /usr/local/sbin"
for f in signage-update signage-deploy-files signage-display-mode signage-takeover-watch; do
  fetch "$RAW/pi-setup/$f" "/usr/local/sbin/$f" 0755
  sh -n "/usr/local/sbin/$f" || die "syntax check failed: $f"
done

say "Installing takeover-watch systemd units"
fetch "$RAW/pi-setup/signage-takeover-watch.service" \
  /etc/systemd/system/signage-takeover-watch.service 0644
fetch "$RAW/pi-setup/signage-takeover-watch.timer" \
  /etc/systemd/system/signage-takeover-watch.timer 0644
systemctl daemon-reload
systemctl enable --now signage-takeover-watch.timer

say "Installing passwordless sudo for signage commands"
fetch "$RAW/pi-setup/signage-sudoers" /etc/sudoers.d/signage 0440
chown root:root /etc/sudoers.d/signage
visudo -c || die "sudoers validation failed"

say "Verifying passwordless sudo as the admin user"
su - admin -s /bin/sh -c 'sudo -k; sudo -n /usr/local/sbin/signage-takeover-watch' \
  || die "passwordless sudo test failed"

say "Fetching pristine Celebrate image"
install -d -o admin -g admin "$SIGNAGE_ROOT"
fetch "$RAW/takeover.png" "$SIGNAGE_ROOT/celebrate.png" 0644
chown admin:admin "$SIGNAGE_ROOT/celebrate.png"

say "Setting standing mode: takeover (Celebrate)"
printf 'MODE=takeover\n' > /etc/default/signage-mode

say "Running mode-aware update from GitHub"
/usr/local/sbin/signage-update

say "Flip test: normal ad (brief)"
[ -f "$SIGNAGE_ROOT/current/normal.html" ] || die "normal.html missing from release"
/usr/local/sbin/signage-display-mode normal
grep -o '<title>[^<]*' "$SIGNAGE_ROOT/current/index.html" || true
sleep 3

say "Flip test: back to Celebrate takeover"
/usr/local/sbin/signage-display-mode takeover
grep -o '<title>[^<]*' "$SIGNAGE_ROOT/current/index.html" || true

say "Pruning old releases (keeping current + newest rollback)"
cur_id=$(basename "$(readlink "$SIGNAGE_ROOT/current")")
keep=$(ls -t "$SIGNAGE_ROOT/releases" | grep -v -x "$cur_id" | head -1)
for d in "$SIGNAGE_ROOT/releases"/*/; do
  [ -d "$d" ] || continue
  id=$(basename "$d")
  if [ "$id" != "$cur_id" ] && [ "$id" != "$keep" ]; then
    echo "  removing old release: $id"
    rm -rf "$d"
  fi
done
echo "  current: $cur_id | rollback: ${keep:-none}"

say "Waiting for the player to settle after the flip test"
for i in $(seq 1 30); do
  if curl -s --max-time 5 http://127.0.0.1:9222/json/list 2>/dev/null \
    | grep -q '"title": "Signage heartbeat [0-9][0-9]* playing"'; then
    echo "  player heartbeat healthy"
    break
  fi
  sleep 2
  if [ "$i" = 30 ]; then
    echo "  WARNING: player heartbeat not seen after 60s; continuing anyway"
  fi
done

say "Triggering health email"
systemctl start signage-health-email.service
sleep 5
systemctl show signage-health-email.service -p ActiveState,Result

say "Final verification"
echo "-- mode: $(cat /etc/default/signage-mode)"
echo "-- release contents:"; ls "$SIGNAGE_ROOT/current"
echo "-- kiosk procs:"; pgrep -a -f "cage|chromium" | head -5 || echo "  (none found)"
echo "-- heartbeat:"
if hb=$(curl -s --max-time 10 http://127.0.0.1:9222/json/list); then
  echo "$hb" | grep -o '"title":"[^"]*"' | head -3 || echo "  (no page title yet — kiosk may still be loading)"
else
  echo "  (no response from Chromium remote debugging)"
fi
echo "-- takeover-watch timer:"; systemctl is-enabled signage-takeover-watch.timer; systemctl is-active signage-takeover-watch.timer
vcgencmd measure_temp 2>/dev/null || true
vcgencmd get_throttled 2>/dev/null || true

say "Done — the Celebrate takeover is live."
