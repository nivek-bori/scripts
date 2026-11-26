# Shared zsh settings. Reload Hammerspoon after editing these.
if [[ $(/usr/bin/uname -m) == arm64 || $(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null) == 1 ]]; then
  brew_prefix=/opt/homebrew
else
  brew_prefix=/usr/local
fi

models_dir="$HOME/.local/share/whisper-tools/models"
language=en
dictation_model=base.en
subtitles_model=small.en

whisper="$brew_prefix/bin/whisper-cli"
ffmpeg="$brew_prefix/bin/ffmpeg"
ffmpeg_full="$brew_prefix/opt/ffmpeg-full/bin/ffmpeg"

model_path() {
  print -r -- "$models_dir/ggml-$1.bin"
}

has_subtitles_filter() {
  "$1" -hide_banner -filters 2>/dev/null | /usr/bin/awk '
    $2 == "subtitles" { found = 1 }
    END { exit !found }
  '
}
