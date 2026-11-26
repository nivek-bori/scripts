# whisper-tools

Local macOS dictation and subtitles. Both use whisper.cpp and FFmpeg. An internet connection is needed for setup and model downloads. Transcription runs offline with no account, API key, or Python.

## Setup

From this repo, on a Mac with Homebrew:

```sh
./install.sh
```

| Location | What setup puts there |
| --- | --- |
| `/opt/homebrew` on Apple Silicon, `/usr/local` on Intel | Homebrew packages `whisper.cpp` (provides `whisper-cli`) and `ffmpeg`, plus `ffmpeg-full` when the installed FFmpeg lacks the `subtitles` filter |
| `/Applications/Hammerspoon.app` | Hammerspoon cask, if Hammerspoon is absent |
| `~/.local/share/whisper-tools/models/` | `ggml-base.en.bin` for dictation and `ggml-small.en.bin` for subtitles |
| `~/bin/subs`, `~/.hammerspoon/whisper-dictation.lua` | Symlinks to this checkout |
| `~/.hammerspoon/init.lua` | Appends `require("whisper-dictation")` when absent and preserves existing contents |
| `~/.zshrc` (or `$ZDOTDIR/.zshrc`) | Adds `~/bin` when absent from `PATH` |

Open a new terminal for the PATH change. Keep the repo in place while using the symlinks. The installer can be rerun. It verifies model files against checksums published by the [official whisper.cpp model repository](https://huggingface.co/ggerganov/whisper.cpp) and only replaces a model after a complete, verified download. Defaults need about 610 MiB of model storage.

## Dictation

### macOS permissions

1. Open **Hammerspoon**. In **System Settings → Privacy & Security → Accessibility**, turn on **Hammerspoon**. If it is absent, click **+** and select `/Applications/Hammerspoon.app`. [Apple’s Accessibility instructions](https://support.apple.com/guide/mac-help/mh43185/mac)
2. Select **Reload Config** from Hammerspoon’s menu bar icon. In a text editor, press **Ctrl+Option+L** and choose **Allow** on the microphone prompt.
3. If you already denied the prompt, enable **Hammerspoon** under **System Settings → Privacy & Security → Microphone**, then quit and reopen Hammerspoon. [Apple’s microphone instructions](https://support.apple.com/guide/mac-help/mchla1b1e1fe/mac)

### Use and verify

- In Hammerspoon’s **Console**, run `assert(require("whisper-dictation").hotkey)` to check that the module loads and returns the hotkey binding.
- Focus a normal text field, copy some sample text, then press **Ctrl+Option+L**. Wait for the alert to change from **Opening microphone…** to **Recording…** before speaking.
- Say a sentence and press the shortcut again. The dot should disappear, **Transcribing…** should appear, and the text should paste at the cursor. Check that your original clipboard returns shortly afterward.
- Try a silent recording and a quick double press. Both should return to idle without pasting a transcript. Then record another sentence to check recovery.

### Troubleshooting

- **Shortcut conflict** → Check **System Settings → Keyboard → Keyboard Shortcuts → Spotlight** and **Input Sources**, or edit `DICTATION_HOTKEY` at the top of the Lua file and reload.
- **Microphone selection** → Dictation uses the macOS default input if it is non-Bluetooth. When the default is a Bluetooth headset, dictation prefers the built-in mic or another non-Bluetooth input to keep playback volume steady. Set `MICROPHONE_INPUT` to a named input such as `":USB Microphone"` to override selection. [Apple’s explanation of Bluetooth playback volume](https://support.apple.com/en-us/102217)
- **Recording or transcription error** → Open the Hammerspoon **Console** for FFmpeg or whisper-cli diagnostics. For another dictation language, set `language` and `dictation_model=base` in `config.sh`, rerun the installer and reload Hammerspoon. The `.en` models only support English.
- **Paste blocked** → Check Accessibility and focus a field that accepts Cmd+V. Secure input fields can block simulated keystrokes.
- **Multiple clipboard items** → Copy a single item before dictating. The module keeps a multi-item clipboard intact when Hammerspoon cannot snapshot every item.

## Subtitles

```sh
subs "meeting clip.mp4" "interview.m4a"
subs "meeting clip.mp4" --vtt
subs "meeting clip.mp4" --burn
./install.sh medium
subs "interview.m4a" --model medium --lang es
```

- **Sidecars** → Writes `<name>.srt` or `<name>.vtt` next to each source. Captions target about 42 characters per segment and split at word boundaries.
- **Models** → `--model small|medium|large` selects small, medium, or large-v3. Run `./install.sh medium large-v3` while online to cache both larger models. For `--lang` other than `en` with the small model, run `./install.sh small` for multilingual weights. `--lang auto` detects the language with multilingual weights.
- **Burn-in** → Also creates `<name>.captioned.mp4` for video inputs. Use `--font-size N` to change the caption size. It encodes the video as H.264 and copies the first audio stream. The source audio codec must be supported by the MP4 container. If rendering fails, the sidecar remains.
- **Batch behavior** → Replaces existing sidecars and captioned outputs with the same names. It reports failed files, continues with the rest, and returns a nonzero exit code if any failed. Use `--` before file arguments beginning with `-`.

### Smoke test

Run these commands in a scratch directory:

```sh
say -o test.aiff "This is a subtitle test"
ffmpeg -f lavfi -i color=c=black:s=640x360:r=25 -i test.aiff \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest sample.mp4
subs sample.mp4
cat sample.srt
subs sample.mp4 --burn
open sample.captioned.mp4
```

The SRT should contain a timed cue with the spoken sentence, and the MP4 should show white captions over a dark box near the bottom.

## Raycast Script Command

Add this repository’s `raycast` folder in **Raycast Settings → Script Commands → Add Script Directory**, then run **Caption Video**.

- **Video path** accepts an absolute or home-relative path. Leave it blank to use all selected files in Finder.
- **Font Size** is a dropdown with a default of `16`. Raycast shows the result in a compact toast.
- **After a successful render**, the command saves or replaces `<name>.captioned.mp4` beside the source, discards the generated SRT, and moves the source to Trash. Files that fail stay in place while the command continues with the selection.

## Finder Quick Action

1. In **Automator → File → New**, choose **Quick Action**.
2. Set **Workflow receives current** to **files or folders** in **Finder**.
3. Add **Run Shell Script**, choose shell **/bin/zsh** and set **Pass input** to **as arguments**.
4. Paste the following action body (also in [finder/subs-quick-action.zsh](finder/subs-quick-action.zsh)):

   ```zsh
   (( $# )) || exit 0
   exec "$HOME/bin/subs" -- "$@"
   ```

5. Save as **Make Subtitles**. Select one or more media files in Finder and choose **Quick Actions → Make Subtitles**. The action uses the default model and writes SRT sidecars.

The same script can run in **Shortcuts**. Set the shortcut to receive **Files** as a Finder Quick Action, get each file's **File Path**, and pass those paths **as arguments** to **Run Shell Script** with `/bin/zsh`. [Apple’s Shortcuts Quick Action instructions](https://support.apple.com/guide/shortcuts-mac/apd163eb9f95/mac)
