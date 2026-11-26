#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Decaffeinate
# @raycast.mode silent

# Documentation:
# @raycast.author nivek_bori
# @raycast.authorURL https://raycast.com/nivek_bori

PID_FILE="${TMPDIR:-/tmp}/raycast-coffee-caffeinate.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No active caffeination session."
  exit 0
fi

CAFFEINATE_PID=$(<"$PID_FILE")

if [[ ! "$CAFFEINATE_PID" =~ ^[0-9]+$ ]] || ! /bin/kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
  /bin/rm -f "$PID_FILE"
  echo "No active caffeination session."
  exit 0
fi

CAFFEINATE_COMMAND=$(/bin/ps -p "$CAFFEINATE_PID" -o comm= 2>/dev/null)
case "$CAFFEINATE_COMMAND" in
  caffeinate|*/caffeinate)
    /bin/kill "$CAFFEINATE_PID"
    /bin/rm -f "$PID_FILE"
    echo "Caffeination stopped."
    ;;
  *)
    /bin/rm -f "$PID_FILE"
    echo "No active caffeination session."
    ;;
esac
