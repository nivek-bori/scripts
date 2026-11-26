#!/bin/zsh

# @raycast.schemaVersion 1
# @raycast.title Caption Video
# @raycast.mode compact
# @raycast.icon 🎬
# @raycast.packageName Whisper Tools
# @raycast.argument1 {"type":"text","placeholder":"Video path or Finder selection","optional":true}
# @raycast.argument2 {"type":"dropdown","placeholder":"Font Size","optional":true,"data":[{"title":"16 (Default)","value":"16"},{"title":"12","value":"12"},{"title":"14","value":"14"},{"title":"18","value":"18"},{"title":"20","value":"20"},{"title":"22","value":"22"},{"title":"24","value":"24"},{"title":"26","value":"26"},{"title":"28","value":"28"},{"title":"32","value":"32"}]}
# @raycast.description Burns captions into one video or the Finder selection and trashes each original after a successful render.

fail() { print -r -- "$*"; return 1; }

subs="${0:A:h:h}/bin/subs"
(( $# <= 2 )) || { fail "Supply a video path and a font size."; exit 2; }
filepath=${1:-}
font_size=${2:-16}
[[ $font_size =~ '^[1-9][0-9]*$' ]] || { fail "Choose a valid font size."; exit 2; }

files=()
if [[ -n $filepath ]]; then
  case "$filepath" in
    /*) files=("$filepath") ;;
    '~/'*) files=("$HOME/${filepath#\~/}") ;;
    '$HOME/'*) files=("$HOME/${filepath#\$HOME/}") ;;
    *) files=("$HOME/$filepath") ;;
  esac
else
  # NUL separators preserve Finder paths containing spaces, commas, or newlines.
  selection=$(/usr/bin/osascript <<'APPLESCRIPT'
set paths to ""
tell application "Finder"
    repeat with selectedItem in (get selection)
        set paths to paths & (POSIX path of (selectedItem as alias)) & (character id 0)
    end repeat
end tell
return paths
APPLESCRIPT
  ) || { fail "Could not read the Finder selection."; exit 1; }
  if [[ -z $selection ]]; then
    fail "Select one or more videos in Finder or enter a video path."
    exit 1
  fi
  files=("${(@0)${selection%$'\0'}}")
fi

check_destination() {
  local destination=$1 item
  if [[ -d $destination && ! -L $destination ]]; then
    fail "Output path is a directory: $destination"
    return 1
  fi
  for item in "${protected_paths[@]}"; do
    if [[ $destination == "$item" || $destination -ef $item ]]; then
      fail "Output conflicts with another file in this batch: $destination"
      return 1
    fi
  done
}

file_signature() {
  /usr/bin/stat -f '%d:%i:%m:%z' -- "$1" 2>/dev/null
}

burn_captions() (
  local input=$1 video=$2 work original rendered
  [[ -f $input && -r $input ]] || { fail "Cannot read: $input"; return 1; }
  check_destination "$video" || return 1
  original=$(file_signature "$input") || { fail "Cannot inspect: $input"; return 1; }

  # Render beside the destination so the completed video can replace the old file atomically.
  work=$(/usr/bin/mktemp -d "${input:h}/.whisper-raycast.XXXXXXXX") || return 1
  trap '/bin/rm -rf -- "$work"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  /bin/ln -s -- "$input" "$work/source" || return 1

  rendered="$work/source.captioned.mp4"
  if ! "$subs" --burn --font-size "$font_size" -- "$work/source" > "$work/subs.log" 2>&1 || [[ ! -s $rendered ]]; then
    /usr/bin/tail -n 8 "$work/subs.log" >&2
    fail "Captioning failed: $input"
    return 1
  fi
  if [[ $(file_signature "$input") != "$original" ]]; then
    fail "Source changed during rendering: $input"
    return 1
  fi
  check_destination "$video" || return 1
  /bin/mv -fh -- "$rendered" "$video" && [[ ! -e $rendered && -s $video ]] ||
    { fail "Could not save: $video"; return 1; }

  if [[ $(file_signature "$input") != "$original" ]]; then
    fail "Source changed before cleanup: $input"
    return 1
  fi
  /usr/bin/trash "$input" || { fail "Could not move to Trash: $input"; return 1; }
)

result=0
completed=0
protected_paths=("${files[@]}")
for file in "${files[@]}"; do
  stem="${file:h}/${${file:t}:r}"
  video="$stem.captioned.mp4"
  previous_video=$(file_signature "$video")
  burn_captions "$file" "$video" 2>&1
  case $? in
    0) (( completed += 1 )) ;;
    130) exit 130 ;;
    143) exit 143 ;;
    *) result=1 ;;
  esac
  if [[ -f $video && $(file_signature "$video") != "$previous_video" ]]; then protected_paths+=("$video"); fi
done
if (( result )); then
  if (( $#files > 1 )); then
    print -r -- "Captioning or cleanup failed for $(( $#files - completed )) of $#files files."
  fi
elif (( completed == 1 )); then
  stem="${${files[1]:t}:r}"
  print -r -- "Saved ${stem//$'\n'/ }.captioned.mp4"
else
  print -r -- "Captioned $completed videos."
fi
exit "$result"
