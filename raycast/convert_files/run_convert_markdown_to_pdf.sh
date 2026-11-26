#!/bin/bash

set -euo pipefail

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Convert Markdown to PDF
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📄
# @raycast.argument1 { "type": "text", "placeholder": "Markdown file path" }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Font size", "data": [{ "title": "Default (10 pt)", "value": "default" }, { "title": "8 pt", "value": "8pt" }, { "title": "9 pt", "value": "9pt" }, { "title": "10 pt", "value": "10pt" }, { "title": "11 pt", "value": "11pt" }] }

# Documentation:
# @raycast.author nivek_bori
# @raycast.authorURL https://raycast.com/nivek_bori

# Raycast does not always inherit the interactive shell's Homebrew PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTER_SCRIPT="$SCRIPT_DIR/../../convert/markdown-to-pdf/md-to-pdf"
INPUT_PATH="${1:-}"
FONT_SIZE="${2:-}"

if [[ -z "$INPUT_PATH" ]]; then
    echo "Error: provide a Markdown file path." >&2
    exit 1
fi

if [[ -z "$FONT_SIZE" ]]; then
    echo "Error: select a font size." >&2
    exit 1
fi

# Raycast may pass pasted paths with an unexpanded home-directory prefix.
case "$INPUT_PATH" in
    '~')
        TARGET_PATH="$HOME"
        ;;
    '~/'*)
        TARGET_PATH="$HOME/${INPUT_PATH#\~/}"
        ;;
    '$HOME')
        TARGET_PATH="$HOME"
        ;;
    '$HOME/'*)
        TARGET_PATH="$HOME/${INPUT_PATH#\$HOME/}"
        ;;
    /*)
        TARGET_PATH="$INPUT_PATH"
        ;;
    *)
        TARGET_PATH="$HOME/$INPUT_PATH"
        ;;
esac

if [[ ! -x "$CONVERTER_SCRIPT" ]]; then
    echo "Error: converter script not found or not executable: $CONVERTER_SCRIPT" >&2
    exit 1
fi

if [[ ! -f "$TARGET_PATH" ]]; then
    echo "Error: Markdown file does not exist: $TARGET_PATH" >&2
    exit 1
fi

CONVERTER_ARGS=(--force)
if [[ "$FONT_SIZE" != "default" ]]; then
    CONVERTER_ARGS+=(--font-size "$FONT_SIZE")
fi

exec "$CONVERTER_SCRIPT" "${CONVERTER_ARGS[@]}" "$TARGET_PATH"
