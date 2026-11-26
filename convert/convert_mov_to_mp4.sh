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

if ! command -v sips >/dev/null 2>&1; then
    echo "Error: sips is not available"
    exit 1
fi

# File finding command depending on recursive flag
if $RECURSIVE; then
    FILES_CMD=(
        find "$DIR"
        -type f
        \( -iname "*.mov" -o -iname "*.heic" \)
        -print0
    )
else
    FILES_CMD=(
        find "$DIR"
        -maxdepth 1
        -type f
        \( -iname "*.mov" -o -iname "*.heic" \)
        -print0
    )
fi

# Actually runs find and processes files
"${FILES_CMD[@]}" |
while IFS= read -r -d '' input_file; do
    extension="${input_file##*.}"

    case "$extension" in
        mov|MOV|Mov|mOv|moV|MOv|mOV|MoV)
            output_file="${input_file%.*}.mp4"

            if [ -s "$output_file" ]; then
                echo "MP4 already exists, deleting MOV:"
                echo "  $input_file"
                rm -- "$input_file"
                continue
            fi

            echo "Converting MOV:"
            echo "  $input_file"
            echo "  -> $output_file"

            ffmpeg \
                -i "$input_file" \
                -c:v libx264 \
                -crf 23 \
                -preset medium \
                -c:a aac \
                -b:a 192k \
                "$output_file"
            ;;

        heic|HEIC|Heic|hEIC|heIC|heiC|HEic|HeIC|hEiC)
            output_file="${input_file%.*}.png"

            if [ -s "$output_file" ]; then
                echo "PNG already exists, deleting HEIC:"
                echo "  $input_file"
                rm -- "$input_file"
                continue
            fi

            echo "Converting HEIC:"
            echo "  $input_file"
            echo "  -> $output_file"

            # sips is run in foreground, no issue here
            sips \
                -s format png \
                "$input_file" \
                --out "$output_file" \
                >/dev/null
            ;;

        *)
            echo "Skipping unsupported file:"
            echo "  $input_file"
            continue
            ;;
    esac

    if [ -s "$output_file" ]; then
        echo "Deleting original:"
        echo "  $input_file"
        rm -- "$input_file"
    else
        echo "Error: output was not created successfully:"
        echo "  $output_file"
    fi
done