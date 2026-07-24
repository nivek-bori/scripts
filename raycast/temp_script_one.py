#!/usr/bin/env python3

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sequence Generator
# @raycast.mode compact

# Optional parameters:
# @raycast.icon Icon.CommandSymbol
# @raycast.argument1 { "type": "text", "placeholder": "Pattern (e.g. E1.1 (120))" }
# @raycast.argument2 { "type": "text", "placeholder": "Count (e.g. 8)" }

# Documentation:
# @raycast.description Replaces the 2nd character with index 1 to N and copies to clipboard.

import sys
import subprocess

def main():
    if len(sys.argv) < 3:
        print("Missing parameters.")
        sys.exit(1)

    template = sys.argv[1]
    
    try:
        count = int(sys.argv[2])
    except ValueError:
        print("Error: Count must be a valid number.")
        sys.exit(1)

    # Replaces 2nd character (index 1) with numbers 1 through count
    items = [template[:1] + str(i) + template[2:] for i in range(1, count + 1)]
    
    # Separating items with tabs creates individual row cells when pasted
    result = "\t".join(items)

    # Copy output to macOS clipboard
    process = subprocess.Popen(['pbcopy'], stdin=subprocess.PIPE)
    process.communicate(result.encode('utf-8'))

    print("Copied sequence to clipboard!")

if __name__ == "__main__":
    main()