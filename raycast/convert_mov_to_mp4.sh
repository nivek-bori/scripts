#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Convert MOV to MP4
# @raycast.mode compact

# Optional parameters:
# @raycast.icon Icon.BlankDocument
# @raycast.argument1 { "type": "text", "placeholder": "Directory Path" }

CONVERTER_SCRIPT="$HOME/Github/scripts/convert_mov_to_mp4.sh"

echo "$CONVERTER_SCRIPT"

if [ ! -x "$CONVERTER_SCRIPT" ]; then
    echo "Converter script not found or not executable:"
    echo "$CONVERTER_SCRIPT"
    exit 1
fi

echo "Running converter script..."
"$CONVERTER_SCRIPT" "$HOME/$1"

echo "Done."