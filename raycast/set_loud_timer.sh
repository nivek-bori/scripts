#!/bin/bash

# ================== Raycast Metadata ==================
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Set Loud Timer
# @raycast.mode compact

# Optional parameters:
# @raycast.icon Icon.Alarm
# @raycast.argument1 { "type": "text", "placeholder": "Minutes", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Seconds", "optional": true }
# ======================================================

# ----- Input Handling -----
MINUTES=${1:-0}
SECONDS_ARG=${2:-0}

# Convert input time to total seconds
TOTAL_SECONDS=$((MINUTES * 60 + SECONDS_ARG))

# Validate input
if [ "$TOTAL_SECONDS" -le 0 ]; then
  echo "Please provide a valid time duration."
  exit 1
fi

# ----- Timer -----
sleep "$TOTAL_SECONDS"

# ----- Audio Configuration -----
ALARM_FILE="/Users/kevinboriboonsomsin/Documents/[scripts]/system_sounds/loud_alarm.mp3"
TEMP_FILE="/tmp/loop_alarm.mp3"
VOLUME_MAX="20"  # Max volume
REPEAT_COUNT=19  # ffmpeg: -stream_loop n plays input n+1 times

# Check alarm file existence
if [ ! -f "$ALARM_FILE" ]; then
  echo "Sound file not found: $ALARM_FILE"
  exit 1
fi

# Ensure afplay is available (macOS)
if ! command -v afplay >/dev/null 2>&1; then
  echo "afplay not found. This script requires macOS."
  exit 1
fi

# ----- Create Temporary Loop File -----
ffmpeg -y -stream_loop $REPEAT_COUNT -i "$ALARM_FILE" -c copy "$TEMP_FILE" 2>/dev/null

# ----- Remember Current Volume, Set to Max -----
OLD_VOLUME=$(osascript -e "output volume of (get volume settings)")
osascript -e "set volume output volume $VOLUME_MAX"

# ----- Play Alarm -----
afplay "$TEMP_FILE"

# ----- Restore Volume -----
osascript -e "set volume output volume $OLD_VOLUME"

# ----- Cleanup -----
rm -f "$TEMP_FILE"