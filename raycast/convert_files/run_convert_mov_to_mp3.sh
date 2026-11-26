#!/bin/bash

set -euo pipefail

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Convert MOV to MP3
# @raycast.mode compact

# Optional parameters:
# @raycast.icon Icon.BlankDocument
# @raycast.argument1 { "type": "text", "placeholder": "Directory Path" }

CONVERTER_SCRIPT="$HOME/Github/scripts/convert/convert_mov_to_mp3.sh"
INPUT_PATH="$1"

case "$INPUT_PATH" in
    '$HOME')
        TARGET_PATH="$HOME"
        ;;
    '$HOME/'*)
        TARGET_PATH="$HOME/${INPUT_PATH#\$HOME/}"
        ;;
    '~')
        TARGET_PATH="$HOME"
        ;;
    '~/'*)
        TARGET_PATH="$HOME/${INPUT_PATH#\~/}"
        ;;
    /*)
        TARGET_PATH="$INPUT_PATH"
        ;;
    *)
        TARGET_PATH="$HOME/$INPUT_PATH"
        ;;
esac

if [ ! -x "$CONVERTER_SCRIPT" ]; then
    echo "Error: converter script not found or not executable: $CONVERTER_SCRIPT" >&2
    exit 1
fi

if [ ! -e "$TARGET_PATH" ]; then
    echo "Error: path does not exist: $TARGET_PATH" >&2
    exit 1
fi

if [ ! -d "$TARGET_PATH" ]; then
    echo "Error: path is not a directory: $TARGET_PATH" >&2
    exit 1
fi

"$CONVERTER_SCRIPT" "$TARGET_PATH"
