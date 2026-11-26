#!/usr/bin/env python3
from pathlib import Path
from shlex import quote


def main():
    script_dir = Path(__file__).resolve().parent
    for name in ("run_spotify.sh", "run_spiced_spotify.sh", "run_unconfig_spotify.sh"):
        print(f"bash {quote(str(script_dir / name))}")


if __name__ == "__main__":
    main()
