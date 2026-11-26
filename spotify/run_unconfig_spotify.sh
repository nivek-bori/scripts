#!/bin/bash
set -eu

script_dir=$(dirname -- "${BASH_SOURCE[0]}")
exec /bin/bash "$script_dir/run_spotify.sh" --interactive
