#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Caffeinate For
# @raycast.mode silent

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Hours", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Minutes", "optional": true }

# Documentation:
# @raycast.author nivek_bori
# @raycast.authorURL https://raycast.com/nivek_bori

HOURS=${1:-0}
MINUTES=${2:-0}
PID_FILE="${TMPDIR:-/tmp}/raycast-coffee-caffeinate.pid"

if [[ ! "$HOURS" =~ ^[0-9]+$ ]] || [[ ! "$MINUTES" =~ ^[0-9]+$ ]]; then
  echo "Hours and minutes must be non-negative whole numbers."
  exit 1
fi

if (( 10#$MINUTES > 59 )); then
  echo "Minutes must be between 0 and 59."
  exit 1
fi

TOTAL_SECONDS=$((10#$HOURS * 3600 + 10#$MINUTES * 60))

if (( TOTAL_SECONDS <= 0 )); then
  echo "Enter a duration greater than zero."
  exit 1
fi

# Replace an existing session created by this script.
if [[ -f "$PID_FILE" ]]; then
  EXISTING_PID=$(<"$PID_FILE")
  if [[ "$EXISTING_PID" =~ ^[0-9]+$ ]] && /bin/kill -0 "$EXISTING_PID" 2>/dev/null; then
    EXISTING_COMMAND=$(/bin/ps -p "$EXISTING_PID" -o comm= 2>/dev/null)
    case "$EXISTING_COMMAND" in
      caffeinate|*/caffeinate) /bin/kill "$EXISTING_PID" 2>/dev/null || true ;;
    esac
  fi
fi

/usr/bin/nohup /usr/bin/caffeinate -dims -t "$TOTAL_SECONDS" >/dev/null 2>&1 &
CAFFEINATE_PID=$!

umask 077
printf '%s\n' "$CAFFEINATE_PID" > "$PID_FILE"

if (( 10#$HOURS == 0 )); then
  echo "Caffeinating for $((10#$MINUTES)) minute(s)."
elif (( 10#$MINUTES == 0 )); then
  echo "Caffeinating for $((10#$HOURS)) hour(s)."
else
  echo "Caffeinating for $((10#$HOURS)) hour(s) and $((10#$MINUTES)) minute(s)."
fi
