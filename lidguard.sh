#!/bin/bash
# lidguard: keep the Mac working with the lid closed, but never drain the battery.
#
# Runs as root every minute (launchd: /Library/LaunchDaemons/com.lidguard.plist).
#   lid open                      -> sleep disabled (closing the lid keeps the Mac awake); the timer resets
#   lid closed                    -> starts counting; past MAX_HOURS the Mac goes to sleep
#   on battery and under MIN_PCT  -> sleep enabled again, lid open or closed (lid closed: sleeps now)
# Config: /etc/lidguard.conf (ENABLED, MAX_HOURS, MIN_BATTERY). Log: /var/log/lidguard.log.
#
# Test without root: LIDGUARD_TEST=1 LID=closed POWER=battery PCT=15 STATE_DIR=/tmp/x CONF=/dev/null ./lidguard.sh

set -u

CONF="${CONF:-/etc/lidguard.conf}"
STATE_DIR="${STATE_DIR:-/var/db/lidguard}"
LOG="${LOG:-/var/log/lidguard.log}"
ENABLED=1
MAX_HOURS=4
MIN_BATTERY=20
# shellcheck disable=SC1090
[ -r "$CONF" ] && . "$CONF"

mkdir -p "$STATE_DIR"
CLOSED_SINCE="$STATE_DIR/closed_since"
TRIPPED="$STATE_DIR/tripped"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

run() {
  if [ "${LIDGUARD_TEST:-0}" = 1 ]; then echo "would run: $*"; else "$@"; fi
}

lid_state() {
  [ -n "${LID:-}" ] && { echo "$LID"; return; }
  if ioreg -r -k AppleClamshellState -d 4 | grep -q '"AppleClamshellState" = Yes'; then echo closed; else echo open; fi
}

power_source() {
  [ -n "${POWER:-}" ] && { echo "$POWER"; return; }
  if pmset -g batt | grep -q "AC Power"; then echo ac; else echo battery; fi
}

battery_pct() {
  [ -n "${PCT:-}" ] && { echo "$PCT"; return; }
  pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%'
}

sleep_disabled() {
  [ -n "${SLEEP_DISABLED:-}" ] && { echo "$SLEEP_DISABLED"; return; }
  pmset -g | awk '/SleepDisabled/ {print $2}'
}

set_sleep_disabled() { # $1 = 0|1
  [ "$(sleep_disabled)" = "$1" ] && return
  run pmset -a disablesleep "$1"
  log "disablesleep -> $1 ($2)"
}

if [ "$ENABLED" != 1 ]; then
  # Turned off: hand sleep back to macOS once, then stay out of the way.
  if [ ! -e "$STATE_DIR/off" ]; then
    set_sleep_disabled 0 "lidguard disabled"
    rm -f "$CLOSED_SINCE" "$TRIPPED"
    touch "$STATE_DIR/off"
  fi
  exit 0
fi
rm -f "$STATE_DIR/off"

now=$(date +%s)
lid=$(lid_state)
power=$(power_source)
pct=$(battery_pct)
low_battery=0
[ "$power" = battery ] && [ -n "$pct" ] && [ "$pct" -lt "$MIN_BATTERY" ] && low_battery=1

if [ "$lid" = open ]; then
  rm -f "$CLOSED_SINCE" "$TRIPPED"
  if [ "$low_battery" = 1 ]; then
    set_sleep_disabled 0 "battery ${pct}% < ${MIN_BATTERY}%, lid open: normal sleep"
  else
    set_sleep_disabled 1 "lid open: closing it keeps the Mac awake"
  fi
  exit 0
fi

# Lid closed.
[ -s "$CLOSED_SINCE" ] || { echo "$now" >"$CLOSED_SINCE"; log "lid closed (power $power, battery ${pct}%)"; }
since=$(cat "$CLOSED_SINCE")
elapsed=$((now - since))
limit=$(awk -v h="$MAX_HOURS" 'BEGIN { printf "%d", h * 3600 }')

reason=""
[ "$elapsed" -ge "$limit" ] && reason="lid closed $((elapsed / 60)) min >= ${MAX_HOURS} h"
[ "$low_battery" = 1 ] && reason="battery ${pct}% < ${MIN_BATTERY}% with the lid closed"

if [ -n "$reason" ]; then
  set_sleep_disabled 0 "$reason"
  [ -e "$TRIPPED" ] || log "sleeping: $reason"
  touch "$TRIPPED"
  run pmset sleepnow >/dev/null
fi
exit 0
