#!/bin/basho

export PS4='+ $(date "+%H:%M:%S") [${BASH_SOURCE##*/}:${LINENO}] '
printf "\n"

# Constants
SPOT_LOC="/Applications/Spotify.app"
TMP_LOC="/tmp/temp_spotify_executable.sh"
DWNLD_LOC="https://raw.githubusercontent.com/SpotX-Official/SpotX-Bash/main/spotx.sh"

# Executed code
printf "DELETING OLD SPOTIFY\n"
set -x
sudo rm -r "$SPOT_LOC"
set +x
printf "\n"

printf "CREATING THE TEMPORARY EXECUTION FILE\n"
set -x
touch "$TMP_LOC"
set +x
printf "\n"

printf "DOWNLOADING CONTENT\n"
set -x
curl -ssL "$DWNLD_LOC" -o "$TMP_LOC" # Downloading content
chmod +x "$TMP_LOC" # Giving permissions
set +x
printf "\n"

# DEBUGGING
# cat "$TMP_LOC"

printf "RUNNING CONTENT\n"
set -x
printf "y\nn\ny\ny\ny\nn\n" | bash "$TMP_LOC"
set +x
printf "\n"

rm "$TMP_LOC"
