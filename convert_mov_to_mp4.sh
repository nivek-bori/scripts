#!/usr/bin/env bash

set -euo pipefail

RECURSIVE=false

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

if $RECURSIVE; then
    FILES_CMD=(find "$DIR" -type f -iname "*.mov")
else
    FILES_CMD=(find "$DIR" -maxdepth 1 -type f -iname "*.mov")
fi

"${FILES_CMD[@]}" | while read -r input_file; do
    output_file="${input_file%.*}.mp4"

    if [ -s "$output_file" ]; then
        echo "MP4 already exists, deleting MOV:"
        echo "  $input_file"
        rm "$input_file"
        continue
    fi

    echo "Converting:"
    echo "  $input_file"
    echo "  -> $output_file"

    ffmpeg -i "$input_file" \
           -c:v libx264 \
           -crf 23 \
           -preset medium \
           -c:a aac \
           -b:a 192k \
           "$output_file"

    if [ -s "$output_file" ]; then
        echo "Deleting original:"
        echo "  $input_file"
        rm "$input_file"
    fi
done