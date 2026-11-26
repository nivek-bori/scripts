#!/usr/bin/python3 -u

# @raycast.schemaVersion 1
# @raycast.title Normalize Audio
# @raycast.mode silent
# @raycast.packageName Audio
# @raycast.icon 🎚️
# @raycast.argument1 {"type": "text", "placeholder": "File path(s) or leave blank for Finder", "optional": true}
# @raycast.description Normalize audio files from a path or the current Finder selection.

import os
import shlex
import subprocess
import sys
from pathlib import Path


def finder_paths():
    result = subprocess.run(
        ["/usr/bin/osascript", "-"],
        input="""
tell application "Finder" to set selectedItems to selection
set quotedPaths to {}
repeat with selectedItem in selectedItems
    tell application "Finder" to set selectedAlias to selectedItem as alias
    set end of quotedPaths to quoted form of (POSIX path of selectedAlias)
end repeat
set AppleScript's text item delimiters to linefeed
return quotedPaths as text
""",
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise RuntimeError(f"Could not read the Finder selection. {result.stderr.strip()}")
    return shlex.split(result.stdout)


def main(arguments):
    paths = [argument for argument in arguments if argument.strip()]
    try:
        if not paths:
            paths = finder_paths()
        elif len(paths) == 1 and not Path(paths[0]).expanduser().is_file():
            paths = shlex.split(paths[0])
    except (OSError, RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    if not paths:
        print("Select files in Finder or enter a file path.", file=sys.stderr)
        return 1

    # Raycast may start with a PATH that excludes Homebrew's FFmpeg.
    os.environ["PATH"] = os.pathsep.join(
        (os.environ.get("PATH") or os.defpath, "/opt/homebrew/bin", "/usr/local/bin")
    )
    normalizer = Path(__file__).resolve().with_name("normalize_audio.py")
    successes = 0
    for path in paths:
        print(f"Normalizing {path}")
        result = subprocess.run([sys.executable, str(normalizer), "--", path])
        if result.returncode == 0:
            successes += 1
        print()

    print(f"Normalized {successes} of {len(paths)} files.")
    return 0 if successes == len(paths) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
