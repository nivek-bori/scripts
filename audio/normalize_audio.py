#!/usr/bin/env python3
"""Normalize the first audio track while preserving video and other tracks."""

MAX_PEAK_DBFS = -1.0
TARGET_RMS_DBFS = -18.0

import argparse
import json
import math
import os
import re
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory


RMS_TOLERANCE_DB = 0.1
MAX_RENDER_ATTEMPTS = 6


def ffmpeg(*args):
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostdin", "-nostats", *args],
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "FFmpeg failed")
    return result.stderr


def stream_copy_options(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "stream=codec_type",
         "-of", "json", str(path)],
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"could not inspect {path.name}")

    streams = json.loads(result.stdout).get("streams", [])
    first_audio = next(
        (index for index, stream in enumerate(streams) if stream.get("codec_type") == "audio"),
        None,
    )
    if first_audio is None:
        raise RuntimeError(f"no audio stream in {path.name}")

    # Mapping the entire input keeps its stream order. Let the muxer choose an
    # audio encoder for the first audio stream, and copy every other stream.
    options = []
    for index in range(len(streams)):
        if index != first_audio:
            options.extend((f"-c:{index}", "copy"))
    return options


def measure(path):
    stats = ffmpeg(
        "-i", str(path), "-map", "0:a:0",
        "-af", "astats=measure_perchannel=none:measure_overall=Peak_level+RMS_level",
        "-f", "null", "-",
    )
    peak = re.search(r"^\[Parsed_astats_[^\n]+\] Peak level dB: (\S+)", stats, re.MULTILINE)
    rms = re.search(r"^\[Parsed_astats_[^\n]+\] RMS level dB: (\S+)", stats, re.MULTILINE)
    if not peak or not rms or "Output file is empty" in stats:
        raise RuntimeError(f"could not measure audio in {path.name}")
    levels = float(peak[1]), float(rms[1])
    if any(not math.isfinite(level) and level != -math.inf for level in levels):
        raise RuntimeError(f"invalid audio levels in {path.name}")
    return levels


def normalize(source, output, *, force=True):
    if force and source.resolve() == output.parent.resolve() / output.name:
        raise RuntimeError("output path is the source file")
    copy_options = stream_copy_options(source)
    input_peak, input_rms = measure(source)
    silent = input_rms == -math.inf
    gain = 0.0 if silent else TARGET_RMS_DBFS - input_rms
    ceiling = MAX_PEAK_DBFS - 0.01
    best_levels = None
    best_error = math.inf

    with TemporaryDirectory(prefix="normalize-audio-", dir=output.parent) as workdir:
        candidate = Path(workdir) / ("candidate" + output.suffix)
        best = Path(workdir) / ("best" + output.suffix)
        codec = ("-c:a:0", "pcm_s24le") if output.suffix.lower() == ".wav" else ()

        for _ in range(MAX_RENDER_ATTEMPTS):
            audio_filter = f"volume={gain}dB:precision=double"
            if input_peak + gain > ceiling:
                # Limit at unity, then scale to the requested ceiling.
                audio_filter = (
                    f"volume={gain - ceiling}dB:precision=double,"
                    "alimiter=limit=1:level=0:latency=1,"
                    f"volume={ceiling}dB:precision=double"
                )
            ffmpeg(
                "-v", "error", "-y", "-copy_unknown", "-i", str(source), "-map", "0",
                *copy_options, "-copyinkf:v", "-filter:a:0", audio_filter, *codec, str(candidate),
            )
            peak, rms = measure(candidate)
            if peak > MAX_PEAK_DBFS:
                # Lossy encoding can raise peaks after the limiter.
                ceiling -= peak - MAX_PEAK_DBFS + 0.05
                continue

            error = 0.0 if silent else abs(TARGET_RMS_DBFS - rms)
            if best_levels is None or error < best_error:
                candidate.replace(best)
                best_levels = peak, rms
                best_error = error
            if error <= RMS_TOLERANCE_DB or rms == -math.inf:
                break
            gain += TARGET_RMS_DBFS - rms

        if best_levels is None:
            raise RuntimeError("could not render audio within the peak ceiling")
        if force:
            best.replace(output)
        else:
            os.link(best, output)

    return best_levels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--force", action=argparse.BooleanOptionalAction, default=True,
        help="replace an existing normalized output",
    )
    parser.add_argument("file", type=Path, help="path to the source audio or video file")
    args = parser.parse_args()

    if not -math.inf < TARGET_RMS_DBFS < MAX_PEAK_DBFS <= 0:
        parser.error("levels must satisfy TARGET_RMS_DBFS < MAX_PEAK_DBFS <= 0")

    source = args.file.expanduser().absolute()
    if not source.is_file() or not source.suffix:
        parser.error("supply an existing media file with a format extension")
    output = source.with_name(f"{source.stem}.normalized{source.suffix}")
    if not args.force and (output.exists() or output.is_symlink()):
        parser.error(f"output already exists: {output}")

    try:
        peak, rms = normalize(source, output, force=args.force)
    except (OSError, RuntimeError) as exc:
        if isinstance(exc, FileNotFoundError) and exc.filename in {"ffmpeg", "ffprobe"}:
            parser.exit(1, f"Error: {exc.filename} from the FFmpeg suite is required on PATH.\n")
        parser.exit(1, f"Error: {exc}\n")

    print(output)
    print(f"Peak: {peak:.2f} dBFS | Average RMS: {rms:.2f} dBFS")
    if rms == -math.inf:
        print("Silent output has no finite RMS level.", file=sys.stderr)
    elif abs(rms - TARGET_RMS_DBFS) > RMS_TOLERANCE_DB:
        print(f"Rendered RMS differs from the {TARGET_RMS_DBFS:g} dBFS target.", file=sys.stderr)


if __name__ == "__main__":
    main()
