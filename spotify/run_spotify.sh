#!/bin/bash
set -eu

with_spotify_lock() (
    if [[ "$OSTYPE" != darwin* ]]; then
        printf 'This Spotify wrapper requires macOS.\n' >&2
        exit 1
    fi

    # The shell holds the lock while the workflow runs, including Spicetify.
    exec 9>>"${TMPDIR:-/tmp}/spotify-workflow-${UID}.lock"
    if ! /usr/bin/lockf -t 0 9; then
        printf 'Could not acquire the Spotify workflow lock. Check for another run.\n' >&2
        exit 1
    fi
    "$@" 9>&-
)

run_spotx() (
    if [[ $# -gt 1 ]]; then
        printf 'Usage: %s [--interactive]\n' "${0##*/}" >&2
        exit 2
    fi
    case "${1:-}" in
        '')
            macos_version=$(sw_vers -productVersion)
            if (( ${macos_version%%.*} < 13 )); then
                printf 'Automatic Spotify installation requires macOS 13 or later.\n' >&2
                exit 1
            fi
            # Match the preset choices independently of SpotX's prompt order.
            spotx_options=(--installmac --noninteractive --clearcache --devmode --hide)
            ;;
        --interactive)
            spotx_options=(--interactive)
            ;;
        *)
            printf 'Usage: %s [--interactive]\n' "${0##*/}" >&2
            exit 2
            ;;
    esac

    installer=$(mktemp "${TMPDIR:-/tmp}/spotify-spotx.XXXXXXXX")
    trap 'rm -f -- "$installer"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    printf 'Downloading SpotX…\n'
    curl --fail --silent --show-error --location --output "$installer" \
        https://raw.githubusercontent.com/SpotX-Official/SpotX-Bash/main/spotx.sh
    if [[ ! -s "$installer" ]]; then
        printf 'SpotX download is empty.\n' >&2
        exit 1
    fi
    /bin/bash -n "$installer"

    printf 'Running SpotX…\n'
    /bin/bash "$installer" "${spotx_options[@]}"
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    with_spotify_lock run_spotx "$@"
fi
