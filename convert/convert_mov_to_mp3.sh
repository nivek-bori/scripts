#!/usr/bin/env bash

set -euo pipefail

RECURSIVE=false

# Argument parsing
if [ "$#" -eq 2 ] && [ "$1" = "-r" ]; then
    RECURSIVE=true
    DIR="$2"
elif [ "$#" -eq 1 ]; then
    DIR="$1"
else
    echo "Usage: $0 [-r] <directory>"
    exit 1
fi

if [ ! -d "$DIR" ]; then
    echo "Error: '$DIR' is not a directory"
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg is not installed or not available in PATH"
    exit 1
fi

# File finding command depending on recursive flag
if $RECURSIVE; then
    FILES_CMD=(
        find "$DIR"
        -type f
        -iname "*.mov"
        -print0
    )
else
    FILES_CMD=(
        find "$DIR"
        -maxdepth 1
        -type f
        -iname "*.mov"
        -print0
    )
fi

# Convert MOV files to MP3
"${FILES_CMD[@]}" |
while IFS= read -r -d '' input_file; do
    output_file="${input_file%.*}.mp3"

    # If a valid MP3 already exists, just remove the MOV
    if [ -s "$output_file" ]; then
        echo "MP3 already exists, deleting MOV:"
        echo "  $input_file"
        rm -- "$input_file"
        continue
    fi

    echo "Converting MOV:"
    echo "  $input_file"
    echo "  -> $output_file"

    ffmpeg \
        -y \
        -i "$input_file" \
        -map 0:a:0 \
        -vn \
        -c:a libmp3lame \
        -b:a 192k \
        -map_metadata 0 \
        "$output_file"

    if [ -s "$output_file" ]; then
        echo "Deleting original:"
        echo "  $input_file"
        rm -- "$input_file"
    else
        echo "Error: output was not created successfully:"
        echo "  $output_file"
    fi
done