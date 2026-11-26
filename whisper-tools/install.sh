#!/bin/zsh
# Honor the zsh requirement even when invoked as `bash install.sh` or `sh install.sh`.
if [ -z "${ZSH_VERSION:-}" ]; then
  exec /bin/zsh "$0" "$@"
fi

set -eu

repo=${0:A:h}
source "$repo/config.sh"

die() { print -ru2 -- "install: $*"; exit 1; }

# Published checksums from huggingface.co/ggerganov/whisper.cpp.
typeset -A sha1=(
  base.en 137c40403d78fd54d454da0f9bd998f78703390c
  base 465707469ff3a37a2b9b8d8f89f2f99de7299dac
  small.en db8a495a91d927739e50b3fc1cc4c6b8f6c2d022
  small 55356645c2b361a969dfd0ef2c5a50d530afd8d5
  medium fd9727b6e1217c2f614f9b698455c4ffd82463b4
  large-v3 ad82bf6a9043ceed055076d0fd39f5f186ff8062
)
models=("$dictation_model" "$subtitles_model" "$@")
typeset -U models
for model in "${models[@]}"; do
  [[ -n ${sha1[$model]:-} ]] || die "Unknown model '$model'. Choose base.en, base, small.en, small, medium or large-v3."
done

brew="$brew_prefix/bin/brew"
[[ -x $brew ]] || die "Homebrew is required at $brew."
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
if [[ ! -x $whisper ]]; then
  "$brew" install whisper.cpp
fi
if [[ ! -x $ffmpeg ]]; then
  "$brew" install ffmpeg
fi
if ! has_subtitles_filter "$ffmpeg" && ! has_subtitles_filter "$ffmpeg_full"; then
  "$brew" install ffmpeg-full
fi
if [[ ! -d /Applications/Hammerspoon.app && ! -d $HOME/Applications/Hammerspoon.app ]] &&
   ! "$brew" list --cask hammerspoon >/dev/null 2>&1; then
  "$brew" install --cask hammerspoon
fi

mkdir -p -- "$models_dir" "$HOME/bin" "$HOME/.hammerspoon"
partial=
trap '[[ -z $partial ]] || rm -f -- "$partial"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

verify_model() {
  # Read via stdin so even a model directory containing a newline hashes cleanly.
  local result
  result=$(/usr/bin/shasum -a 1 < "$1") || return 1
  [[ ${result%% *} == "$2" ]]
}

for model in "${models[@]}"; do
  file=$(model_path "$model")
  if [[ -f $file ]] && verify_model "$file" "${sha1[$model]}"; then
    print -r -- "Verified $file"
    continue
  fi
  [[ ! -d $file ]] || die "Model path is a directory: $file"
  print -r -- "Downloading ggml-$model.bin…"
  partial=$(mktemp "$models_dir/.ggml-$model.XXXXXXXX")
  /usr/bin/curl -q --fail --location --retry 3 --output "$partial" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$model.bin"
  verify_model "$partial" "${sha1[$model]}" || die "Checksum mismatch for ggml-$model.bin."
  mv -fh -- "$partial" "$file"
  partial=
done

install_link() {
  local target=$1 destination=$2
  if [[ -L $destination && ${destination:A} == "$target" ]]; then
    return
  fi
  [[ ! -e $destination && ! -L $destination ]] || die "Already exists: $destination"
  ln -s -- "$target" "$destination"
}

install_link "$repo/bin/subs" "$HOME/bin/subs"
install_link "$repo/hammerspoon/whisper-dictation.lua" "$HOME/.hammerspoon/whisper-dictation.lua"

init="$HOME/.hammerspoon/init.lua"
if [[ ! -f $init ]] ||
   ! /usr/bin/grep -Eq "^[[:space:]]*require[[:space:]]*\([[:space:]]*['\"]whisper-dictation['\"][[:space:]]*\)[[:space:]]*;?[[:space:]]*(--.*)?$" "$init"; then
  printf '\nrequire("whisper-dictation")\n' >> "$init"
fi

zshrc="${ZDOTDIR:-$HOME}/.zshrc"
path_line='export PATH="$HOME/bin:$PATH"'
if [[ ":$PATH:" != *":$HOME/bin:"* ]] &&
   { [[ ! -f $zshrc ]] || ! /usr/bin/grep -Fxq -- "$path_line" "$zshrc"; }; then
  printf '\n%s\n' "$path_line" >> "$zshrc"
  print -r -- "Added ~/bin to PATH in $zshrc. Open a new terminal to use subs."
fi
print -r -- "Installed ~/bin/subs and ~/.hammerspoon/whisper-dictation.lua. Reload Hammerspoon to enable dictation."
