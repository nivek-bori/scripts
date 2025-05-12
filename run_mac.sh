#!/bin/bash

export PS4='+ $(date "+%H:%M:%S") [${BASH_SOURCE##*/}:${LINENO}] '

LOC="tmp/temp_mac_executable.sh"

set -x

touch "$LOC"

# curl -sL "https://raw.githubusercontent.com/nivek-bori/Spoffing/refs/heads/main/mac.sh" -o "$LOC"

# # Give permissions
# chmod +x "$LOC"

# # Run Executable
# "$LOC"

# # Remove executable
# rm "$LOC"

# set +x