#!/bin/bash

LOC="tmp/temp_mac_executable"

curl -sL "https://raw.githubusercontent.com/nivek-bori/Spoffing/refs/heads/main/mac.sh" -o "$LOC"

# Give permissions
chmod +x "$LOC"

# Run Executable
"$LOC"

# Remove executable
rm "$LOC"
