#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Spotify Refresh
# @raycast.mode compact

# Optional parameters:
# @raycast.icon Icon.Music

# Documentation:
# @raycast.author nivek_bori
# @raycast.authorURL https://raycast.com/nivek_bori

open "/Applications/Ghostty.app"
echo -n "bash <(curl -sSL https://raw.githubusercontent.com/nivek-bori/scripts/refs/heads/main/run_spiced_spotify.sh) && spicetify backup apply && spicetify apply" | pbcopy