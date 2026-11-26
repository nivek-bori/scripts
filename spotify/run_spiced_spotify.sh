#!/bin/bash
set -eu

script_dir=$(dirname -- "${BASH_SOURCE[0]}")
source "$script_dir/run_spotify.sh"

download() {
    curl --fail --silent --show-error --location --output "$staging_dir/$2" "$1"
    if [[ ! -s "$staging_dir/$2" ]]; then
        printf 'Download is empty: %s\n' "$1" >&2
        exit 1
    fi
}

run_spicetify_setup() {
    # Raycast may omit Homebrew and standalone CLI locations from its PATH.
    export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.spicetify"
    if ! command -v spicetify >/dev/null; then
        printf 'Install Spicetify CLI before running this script.\n' >&2
        exit 1
    fi

    config_file=$(spicetify -c)
    if [[ "$config_file" != /*/config-xpui.ini ]]; then
        printf 'Unable to determine the Spicetify config directory.\n' >&2
        exit 1
    fi
    spicetify_dir=${config_file%/*}
    extensions_dir="$spicetify_dir/Extensions"
    theme_name=Text
    if [[ ! -d "$spicetify_dir/Themes/Text" && -d "$spicetify_dir/Themes/text" ]]; then
        theme_name=text
    fi
    theme_dir="$spicetify_dir/Themes/$theme_name"

    mkdir -p -- "$spicetify_dir"
    staging_dir=$(mktemp -d "$spicetify_dir/.spotify-assets.XXXXXXXX")
    trap 'rm -rf -- "$staging_dir"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    raw_github=https://raw.githubusercontent.com
    theme_url="$raw_github/spicetify/spicetify-themes/master/text"
    extensions=(shuffle_plus.js scannable.js beautiful_lyrics.mjs)

    printf 'Downloading Spicetify assets…\n'
    download "$raw_github/spicetify/cli/main/Extensions/shuffle%2B.js" shuffle_plus.js
    download "$raw_github/ohitstom/spicetify-extensions/main/scannables/scannables.js" scannable.js
    download "$raw_github/surfbryce/beautiful-lyrics/main/Builds/Release/beautiful-lyrics.mjs" beautiful_lyrics.mjs
    for asset in color.ini user.css; do
        if [[ ! -s "$theme_dir/$asset" ]]; then
            download "$theme_url/$asset" "$asset"
        fi
    done

    mkdir -p -- "$extensions_dir" "$theme_dir"
    run_spotx
    for extension in "${extensions[@]}"; do
        mv -f -- "$staging_dir/$extension" "$extensions_dir/$extension"
    done
    for asset in color.ini user.css; do
        if [[ -f "$staging_dir/$asset" ]]; then
            mv -f -- "$staging_dir/$asset" "$theme_dir/$asset"
        fi
    done

    printf 'Applying Spicetify…\n'
    spicetify config current_theme "$theme_name" color_scheme Spotify \
        extensions "${extensions[0]}" extensions "${extensions[1]}" extensions "${extensions[2]}"
    spicetify backup apply
}

with_spotify_lock run_spicetify_setup
