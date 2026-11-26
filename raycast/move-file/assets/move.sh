#!/bin/bash

set -euo pipefail

SOURCE_INPUT="${1:-$HOME/Downloads}"
TARGET_INPUT="${2:-}"

if [[ -z "$TARGET_INPUT" ]]; then
    echo "Error: provide a destination file or directory path." >&2
    exit 1
fi

# Raycast passes paths as literal strings, so expand the common home-directory forms.
expand_path() {
    case "$1" in
        '~')
            printf '%s\n' "$HOME"
            ;;
        '~/'*)
            printf '%s\n' "$HOME/${1#\~/}"
            ;;
        '$HOME')
            printf '%s\n' "$HOME"
            ;;
        '$HOME/'*)
            printf '%s\n' "$HOME/${1#\$HOME/}"
            ;;
        /*)
            printf '%s\n' "$1"
            ;;
        *)
            printf '%s\n' "$HOME/$1"
            ;;
    esac
}

SOURCE_PATH="$(expand_path "$SOURCE_INPUT")"
TARGET_PATH="$(expand_path "$TARGET_INPUT")"

if [[ ! -d "$SOURCE_PATH" && ! -f "$SOURCE_PATH" ]]; then
    echo "Error: source must be an existing file or directory: $SOURCE_PATH" >&2
    exit 1
fi

if [[ ! -d "$TARGET_PATH" && ! -f "$TARGET_PATH" ]]; then
    echo "Error: destination must be an existing file or directory: $TARGET_PATH" >&2
    exit 1
fi

if [[ -d "$SOURCE_PATH" ]]; then
    # Find the newest regular file directly inside the source directory. Arrays
    # keep unusual filenames (including spaces and newlines) intact.
    shopt -s nullglob dotglob
    SOURCE_ENTRIES=("$SOURCE_PATH"/*)
    LATEST_FILE=""
    LATEST_MTIME=-1

    for CANDIDATE in "${SOURCE_ENTRIES[@]}"; do
        [[ -f "$CANDIDATE" ]] || continue

        CANDIDATE_MTIME="$(stat -f '%m' "$CANDIDATE")"
        if (( CANDIDATE_MTIME > LATEST_MTIME )); then
            LATEST_FILE="$CANDIDATE"
            LATEST_MTIME="$CANDIDATE_MTIME"
        fi
    done
else
    LATEST_FILE="$SOURCE_PATH"
fi

if [[ -z "$LATEST_FILE" ]]; then
    echo "Error: no files found in $SOURCE_PATH" >&2
    exit 1
fi

if [[ -d "$TARGET_PATH" ]]; then
    DESTINATION="$TARGET_PATH/$(basename "$LATEST_FILE")"
else
    DESTINATION="$TARGET_PATH"
fi

if [[ -e "$DESTINATION" && "$LATEST_FILE" -ef "$DESTINATION" ]]; then
    echo "File is already at the destination: $DESTINATION"
    exit 0
fi

mv -f "$LATEST_FILE" "$DESTINATION"
echo "Moved $(basename "$LATEST_FILE") to $DESTINATION"
