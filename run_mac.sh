#!/bin/bash

export PS4='+ $(date "+%H:%M:%S") [${BASH_SOURCE##*/}:${LINENO}] '
printf "\n"

# Constants
TMP_LOC="/tmp/temp_mac_executable.sh"
DWNLD_LOC="https://raw.githubusercontent.com/nivek-bori/scripts/refs/heads/main/mac.sh?token=GHSAT0AAAAAAC72TNX5Q74IC2UNECSK27YU2BCPPIA"

# Executed code
printf "CREATING THE TEMPORARY EXECUTION FILE\n"
set -x
touch "$TMP_LOC"
set +x
printf "\n"

printf "DOWNLOADING CONTENT\n"
set -x
curl -sL "$DWNLD_LOC" -o "$TMP_LOC" # Downloading content
chmod +x "$TMP_LOC" # Giving permissions
set +x
printf "\n"

# cat "$TMP_LOC"

printf "RUNNING CONTENT\n"
set -x
sudo bash "$TMP_LOC"
set +x
printf "\n"

rm "$TMP_LOC"
