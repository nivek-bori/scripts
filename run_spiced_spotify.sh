#!/bin/bash

export PS4='+ $(date "+%H:%M:%S") [${BASH_SOURCE##*/}:${LINENO}] '
printf "\n"

# Constants
SPOT_LOC="/Applications/Spotify.app"
EXEC_LOC="/tmp/temp_spotify_executable.sh"
DWNLD_LOC="https://raw.githubusercontent.com/SpotX-Official/SpotX-Bash/main/spotx.sh"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    SPICETIFY_LOC="$HOME/.config/spicetify"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash or Cygwin)
    SPICETIFY_LOC="$APPDATA/spicetify"
else
    # Linux
    SPICETIFY_LOC="$HOME/.config/spicetify"
fi

# Executed code
printf "DELETING OLD SPOTIFY\n"
set -x
sudo rm -r "$SPOT_LOC"
set +x
printf "\n"

printf "CREATING THE TEMPORARY EXECUTION FILE\n"
set -x
touch "$EXEC_LOC"
set +x
printf "\n"

printf "DOWNLOADING CONTENT\n"
set -x
curl -ssL "$DWNLD_LOC" -o "$EXEC_LOC" # Downloading content
chmod +x "$TMP_LOC" # Giving permissions
set +x
printf "\n"

# DEBUGGING
# cat "$TMP_LOC"

printf "RUNNING CONTENT\n"
set -x
printf "y\nn\ny\ny\ny\nn\n" | bash "$EXEC_LOC"
set +x
printf "\n"

printf "DOWNLOADING SPICETIFY EXTENSIONS"
set -x
cd SPICETIFY_LOC
cd Extensions
curl -o shuffle_plus.js https://raw.githubusercontent.com/spicetify/cli/refs/heads/main/Extensions/shuffle%2B.js
curl -o scannables.js https://raw.githubusercontent.com/ohitstom/spicetify-extensions/refs/heads/main/scannables/scannables.js
curl -o beautiful_lyrics.mjs https://raw.githubusercontent.com/surfbryce/beautiful-lyrics/refs/heads/main/Builds/Release/beautiful-lyrics.mjs

printf "APPLYING SPICETIFY\n"
set -x
chmod +x /opt/homebrew/bin/spicetify
spicetify backup apply
spicetify config current_theme Text
spicetify config color_scheme SPOTIFY
spicetify config extensions shuffle_plus.js
spicetify config extensions scannables.js
spicetify config extensions beautiful_lyrics.mjs
spicetify apply
set +x
printf "\n"

rm "$TMP_LOC"
