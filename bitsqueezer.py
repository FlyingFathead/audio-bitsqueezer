#!/usr/bin/env python3
"""
bitsqueezer.py
==============
(Official repository at: https://github.com/FlyingFathead/audio-bitsqueezer)

All-in-one tool that:
1) Reads any audio file format supported by FFmpeg (via pydub).
2) Downmixes to mono.
3) Optionally trims leading/trailing silence (enabled by default, disable via --no-trim).
4) Optionally "maximizes" the audio to a certain dBFS level (enabled by default, disable via --no-maximize).
5) Optionally applies a "telephone-style" band-pass if desired (300–3400 Hz).
6) Resamples to desired rate.
7) Either:
    - 4-bit raw nibble output (for direct volume-register playback).
    - 8-bit WAV at 6 kHz (for MSSIAH Wave-Player disk import).

Also warns if the final audio exceeds a user-set "max duration"
(default ~5.5 s) for MSSIAH memory constraints.
"""

version_number = 0.12

import sys
import os
import subprocess
import argparse
import struct
from pydub import AudioSegment
from pydub.silence import detect_silence
from pydub.effects import high_pass_filter, low_pass_filter  # for phone-like filtering

# -------------------------
# Default global variables
# -------------------------
TRIM_SILENCE   = True     # If True, leading/trailing silence is trimmed
MAXIMIZE       = True     # If True, we apply a simple "normalize" to a dB level
MAXIMIZE_LEVEL = 0.0      # Default target loudness in dBFS (0.0 => full scale)
STRETCH_4BIT   = True     # If True, we apply nibble distribution stretching to [0..15]

DEFAULT_4BIT_RATE = 4000  # The default sample rate for 4-bit mode
APPLY_TELEPHONE_FILTER = False  # If True, we'll do ~300–3400 Hz band-pass
# -------------------------


def check_ffmpeg_installed():
    """
    Check if 'ffmpeg' is accessible on the system PATH.
    Exits if not found or if calling `ffmpeg -version` fails.
    """
    try:
        subprocess.run(
            ["ffmpeg", "-version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("ERROR: 'ffmpeg' not found or not working. Please install or add it to PATH.")
        sys.exit(1)


def warn_if_too_long(audio_duration, max_sec=5.5):
    """
    Print a warning if audio_duration (in seconds) exceeds max_sec.
    """
    if audio_duration > max_sec:
        print(f"[WARNING] Final audio is ~{audio_duration:.2f} s, "
              f"exceeds recommended limit of {max_sec} s for MSSIAH memory.")


def trim_silence(audio, silence_thresh=-50.0, keep_silence=200):
    """
    Trim leading and trailing silence from 'audio' above 'silence_thresh' dBFS.
    keep_silence (ms) is how many ms to keep at each end after detection.
    """
    if audio.duration_seconds <= 0:
        return audio  # no data

    silences = detect_silence(audio, min_silence_len=100, silence_thresh=silence_thresh)
    if not silences:
        return audio  # no silence found

    leading_sil = 0
    trailing_sil = len(audio)

    # if the first chunk starts at 0 => leading silence
    if silences[0][0] == 0:
        leading_sil = silences[0][1]
    # if the last chunk ends at len(audio) => trailing silence
    if silences[-1][1] == len(audio):
        trailing_sil = silences[-1][0]

    start_cut = max(0, leading_sil - keep_silence)
    end_cut   = min(len(audio), trailing_sil + keep_silence)
    trimmed   = audio[start_cut:end_cut]
    return trimmed if trimmed.duration_seconds > 0 else audio


def do_maximize(audio, target_dbfs=0.0):
    """
    Simple "maximize" or "normalize" by shifting audio so that
    its peak amplitude is at 'target_dbfs'.
    """
    change_in_dB = target_dbfs - audio.max_dBFS
    return audio.apply_gain(change_in_dB)


def apply_telephone_filter(audio):
    """
    Roughly emulate a telephone band-pass by:
      1) high-pass ~300 Hz
      2) low-pass ~3400 Hz
    """
    # high-pass first
    filtered = high_pass_filter(audio, cutoff=300)
    # then low-pass
    filtered = low_pass_filter(filtered, cutoff=3400)
    return filtered


def write_4bit_raw(audio, out_filename, sample_rate, max_sec=9999.0, stretch_4bit=True):
    """
    Convert 'audio' to 4-bit raw nibble data, pack 2 nibbles/byte,
    then write to 'out_filename'.
    """
    # ensure mono
    if audio.channels != 1:
        audio = audio.set_channels(1)
    # resample if needed
    if audio.frame_rate != sample_rate:
        audio = audio.set_frame_rate(sample_rate)

    warn_if_too_long(audio.duration_seconds, max_sec=max_sec)

    # convert to 16-bit
    audio = audio.set_sample_width(2)
    raw_samples = audio.raw_data
    num_samples = len(raw_samples) // 2  # 2 bytes per sample

    samples = struct.unpack("<" + "h"*num_samples, raw_samples)

    # quantize each sample to 4 bits
    nibbles = []
    for s in samples:
        if s < -32768: s = -32768
        elif s > 32767: s = 32767
        shifted = s + 32768  # map [-32768..32767] => [0..65535]
        val_4bit = (shifted >> 12) & 0x0F
        nibbles.append(val_4bit)

    if stretch_4bit:
        # rescale nibble distribution => [0..15]
        nmin = min(nibbles) if nibbles else 0
        nmax = max(nibbles) if nibbles else 15
        if nmax > nmin:
            span = nmax - nmin
            for i in range(len(nibbles)):
                x = nibbles[i] - nmin
                x = int((x * 15) / span + 0.5)
                nibbles[i] = max(0, min(15, x))

    # pack 2 nibbles per byte
    packed = bytearray()
    for i in range(0, len(nibbles), 2):
        lo = nibbles[i]
        hi = nibbles[i+1] if (i+1 < len(nibbles)) else 0
        packed.append((hi << 4) | lo)

    with open(out_filename, "wb") as f:
        f.write(packed)

    print(f"[4bit RAW] {out_filename} written.")
    print(f"Sample rate: {sample_rate} Hz, total samples: {len(samples)}, packed bytes: {len(packed)}")
    if stretch_4bit:
        print("    (Applied nibble distribution stretch to [0..15].)")


def write_mssiah_wav(audio, out_filename, max_sec=5.5):
    """
    Convert 'audio' to 6 kHz, 8-bit mono WAV for MSSIAH Wave-Player disk import.
    """
    # ensure mono
    if audio.channels != 1:
        audio = audio.set_channels(1)
    # force 6 kHz
    if audio.frame_rate != 6000:
        audio = audio.set_frame_rate(6000)
    # force 8-bit
    audio = audio.set_sample_width(1)

    warn_if_too_long(audio.duration_seconds, max_sec=max_sec)

    audio.export(out_filename, format="wav")
    print(f"[MSSIAH WAV] {out_filename} written.")
    print(f"    8-bit, 6 kHz, mono, duration ~{audio.duration_seconds:.2f}s")


def main():
    check_ffmpeg_installed()

    parser = argparse.ArgumentParser(
        description="Convert audio for old-school usage: 4-bit RAW or MSSIAH-friendly 8-bit WAV."
    )
    parser.add_argument("infile", help="Input audio file (any format ffmpeg supports)")
    parser.add_argument("--out",
                        help="Output file name (if not specified, auto-naming is used).")
    parser.add_argument("--mode", choices=["4bit","mssiah"], default="4bit",
                        help="Output mode: '4bit' raw or 'mssiah' 8-bit 6kHz WAV (default: 4bit).")
    parser.add_argument("--rate", type=int, default=DEFAULT_4BIT_RATE,
                        help=f"Sample rate for 4bit mode (default: {DEFAULT_4BIT_RATE}). Ignored in mssiah mode.")
    parser.add_argument("--max", type=float, default=5.5,
                        help="Warn if final audio length > this many seconds (default: 5.5).")

    parser.add_argument("--no-trim", action="store_true",
                        help="Disable trimming of leading/trailing silence (default on).")
    parser.add_argument("--no-maximize", action="store_true",
                        help="Disable the maximizing step (default on).")
    parser.add_argument("--maximize-level", type=float, default=None,
                        help="Target dBFS for maximizing (default=0.0).")
    parser.add_argument("--no-stretch-4bit", action="store_true",
                        help="Disable nibble distribution stretch to [0..15] (default=ON).")
    parser.add_argument("--telco", action="store_true",
                        help="Apply telephone-like band-pass (~300–3400 Hz).")

    args = parser.parse_args()

    # Overwrite global defaults
    global TRIM_SILENCE, MAXIMIZE, MAXIMIZE_LEVEL, STRETCH_4BIT, APPLY_TELEPHONE_FILTER

    if args.no_trim:
        TRIM_SILENCE = False
    if args.no_maximize:
        MAXIMIZE = False
    if args.maximize_level is not None:
        MAXIMIZE_LEVEL = args.maximize_level
    if args.no_stretch_4bit:
        STRETCH_4BIT = False
    if args.telco:
        APPLY_TELEPHONE_FILTER = True

    # Check input file
    if not os.path.isfile(args.infile):
        print(f"ERROR: cannot find input file '{args.infile}'")
        sys.exit(1)

    # Decide on output filename if not set
    if not args.out:
        base, _ = os.path.splitext(args.infile)
        if args.mode == "4bit":
            out_name = f"{base}_4bit_{args.rate}hz.raw"
        else:
            out_name = f"{base}_mssiah_6khz.wav"
    else:
        # user-provided output name
        out_name = args.out

    # Load the audio
    try:
        audio = AudioSegment.from_file(args.infile)
    except Exception as e:
        print(f"ERROR reading input file: {e}")
        sys.exit(1)

    # 1) Trim silence
    if TRIM_SILENCE:
        audio = trim_silence(audio, silence_thresh=-50.0, keep_silence=100)

    # 2) Optional telephone filter
    if APPLY_TELEPHONE_FILTER:
        audio = apply_telephone_filter(audio)

    # 3) Optional maximize
    if MAXIMIZE:
        audio = do_maximize(audio, target_dbfs=MAXIMIZE_LEVEL)

    # 4) Export
    if args.mode == "4bit":
        write_4bit_raw(
            audio=audio,
            out_filename=out_name,
            sample_rate=args.rate,
            max_sec=args.max,
            stretch_4bit=STRETCH_4BIT
        )
    else:
        write_mssiah_wav(audio, out_name, max_sec=args.max)


if __name__ == "__main__":
    main()
