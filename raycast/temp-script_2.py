#!/usr/bin/env python3

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sequence Modifier
# @raycast.mode compact

# Optional parameters:
# @raycast.icon Icon.CommandSymbol
# @raycast.argument1 { "type": "text", "placeholder": "Text (e.g. E1.3 (300)E2.3 (200))" }
# @raycast.argument2 { "type": "text", "placeholder": "New Digit (e.g. 4)" }

# Documentation:
# @raycast.description Replaces the 2nd digit (4th character) in patterns like E1.3 -> E1.4 and tab-separates for row pasting.

import sys
import re
import subprocess

def main():
    if len(sys.argv) < 3:
        print("Missing parameters.")
        sys.exit(1)

    text = sys.argv[1]
    new_digit = sys.argv[2]

    # Replaces 4th character (2nd digit in patterns like E1.3 -> E1.<new_digit>)
    result = re.sub(r'([A-Za-z]\d\.)\d', rf'\g<1>{new_digit}', text)

    # Inserts a tab between concatenated items like ")E" so each item pastes into its own cell
    result = re.sub(r'\)(?=[A-Za-z])', ')\t', result)

    # Copy output to macOS clipboard
    process = subprocess.Popen(['pbcopy'], stdin=subprocess.PIPE)
    process.communicate(result.encode('utf-8'))

    print(f"Copied updated sequence with digit '{new_digit}' to clipboard!")

if __name__ == "__main__":
    main()