#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Get Week
# @raycast.mode compact

# Optional parameters:
# @raycast.icon Icon.Clock

# Documentation:
# @raycast.author nivek_bori
# @raycast.authorURL https://raycast.com/nivek_bori

week=$(date +%V)
formatted="w${week}"

echo -n "$formatted" | pbcopy
echo "$formatted copied to clipboard"

