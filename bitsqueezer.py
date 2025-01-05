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
5) Resamples to desired rate.
6) Either:
    - 4-bit raw nibble output (for direct volume-register playback).
    - 8-bit WAV at 6 kHz (for MSSIAH Wave-Player disk import).

Also warns if the final audio exceeds a user-set "max duration"
(default ~5.5 s) for MSSIAH memory constraints.

Usage examples:
---------------
    # Produce a 4-bit raw file at default 8000 Hz (trim silence + maximize both ON):
    python bitsqueezer.py input.wav --mode 4bit

    # Same, but specify sample rate = 11025, disable trimming:
    python bitsqueezer.py input.wav --mode 4bit --rate 11025 --no-trim

    # Also disable maximizing, or choose a custom level:
    python bitsqueezer.py input.wav --mode 4bit --no-maximize --maximize-level -1.0

    # Produce a MSSIAH-compatible 6 kHz, 8-bit WAV:
    python bitsqueezer.py input.wav --mode mssiah

    # If you want to rename output:
    python bitsqueezer.py input.wav --mode mssiah --out myMSSIAH.wav

Dependencies:
-------------
 - ffmpeg (installed system-wide, must be on PATH)
 - pydub (pip install pydub)
"""

import sys
import os
import subprocess
import argparse
import struct
from pydub import AudioSegment
from pydub.silence import detect_silence

# -------------------------
# Default global variables
# -------------------------
TRIM_SILENCE = True     # If True, leading/trailing silence is trimmed
MAXIMIZE     = True     # If True, we apply a simple "normalize" to a dB level
MAXIMIZE_LEVEL = 0.0    # Default target loudness in dBFS (0.0 => full scale)
# -------------------------

def check_ffmpeg_installed():
    """
    Check if 'ffmpeg' is accessible on the system PATH.
    Exits if not found or if calling `ffmpeg -version` fails.
    """
    try:
        proc = subprocess.run(
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
    Returns a possibly shortened AudioSegment.
    """
    if audio.duration_seconds <= 0:
        return audio  # no data at all

    silences = detect_silence(audio, min_silence_len=100, silence_thresh=silence_thresh)
    if not silences:
        return audio  # no silence found at edges

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
    trimmed = audio[start_cut:end_cut]
    return trimmed if trimmed.duration_seconds > 0 else audio

def do_maximize(audio, target_dbfs=0.0):
    """
    Simple "maximize" or "normalize" by shifting audio so that
    its peak amplitude is at 'target_dbfs'.
    Example: target_dbfs=0.0 => peaks at 0 dBFS (full scale).
    """
    # If audio is silent or already at/above target, .apply_gain may do the trick
    change_in_dB = target_dbfs - audio.max_dBFS
    return audio.apply_gain(change_in_dB)

def write_4bit_raw(audio, out_filename, sample_rate, max_sec=9999.0):
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

    # final length warning
    warn_if_too_long(audio.duration_seconds, max_sec=max_sec)

    # convert to 16-bit
    audio = audio.set_sample_width(2)
    raw_samples = audio.raw_data
    num_samples = len(raw_samples) // 2  # 2 bytes per sample

    samples = struct.unpack("<" + "h" * num_samples, raw_samples)

    # quantize each sample to 4 bits
    nibbles = []
    for s in samples:
        # clamp
        if s < -32768: s = -32768
        elif s > 32767: s = 32767
        shifted = s + 32768  # [0..65535]
        val_4bit = (shifted >> 12) & 0x0F  # [0..15]
        nibbles.append(val_4bit)

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

def write_mssiah_wav(audio, out_filename, max_sec=5.5):
    """
    Convert 'audio' to 6 kHz, 8-bit mono WAV for MSSIAH Wave-Player disk import.
    Warn if it's >5.5s. Then rename .wav => .PRG if needed for usage.
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
    parser.add_argument("--out", help="Output file name")
    parser.add_argument("--mode", choices=["4bit","mssiah"], default="4bit",
                        help="Output mode: '4bit' raw nibbles or 'mssiah' 8-bit 6kHz WAV (default: 4bit)")
    parser.add_argument("--rate", type=int, default=8000,
                        help="Sample rate for 4bit mode (default: 8000). Ignored in mssiah mode.")
    parser.add_argument("--max", type=float, default=5.5,
                        help="Warn if final audio length > this many seconds (default: 5.5).")

    # flags to override the global defaults
    parser.add_argument("--no-trim", action="store_true",
                        help="Disable trimming of leading/trailing silence (default on).")
    parser.add_argument("--no-maximize", action="store_true",
                        help="Disable the maximizing (normalization) step (default on).")
    parser.add_argument("--maximize-level", type=float, default=None,
                        help="Target dBFS for maximizing. Default is 0.0 dBFS if not specified.")

    args = parser.parse_args()

    # Overwrite the global defaults if user provided flags:
    global TRIM_SILENCE, MAXIMIZE, MAXIMIZE_LEVEL

    if args.no_trim:
        TRIM_SILENCE = False
    if args.no_maximize:
        MAXIMIZE = False
    if args.maximize_level is not None:
        MAXIMIZE_LEVEL = args.maximize_level

    if not os.path.isfile(args.infile):
        print(f"ERROR: cannot find input file '{args.infile}'")
        sys.exit(1)

    # Decide on output filename
    if not args.out:
        base, ext = os.path.splitext(args.infile)
        if args.mode == "4bit":
            out_name = f"{base}_4bit_{args.rate}hz.raw"
        else:
            out_name = f"{base}_mssiah_6khz.wav"
    else:
        out_name = args.out

    # Load
    try:
        audio = AudioSegment.from_file(args.infile)
    except Exception as e:
        print(f"ERROR reading input file: {e}")
        sys.exit(1)

    # 1) Trim silence if enabled
    if TRIM_SILENCE:
        audio = trim_silence(audio, silence_thresh=-50.0, keep_silence=100)

    # 2) Maximize if enabled
    if MAXIMIZE:
        audio = do_maximize(audio, target_dbfs=MAXIMIZE_LEVEL)

    # 3) Then produce either 4-bit raw or MSSIAH WAV
    if args.mode == "4bit":
        write_4bit_raw(audio, out_name, sample_rate=args.rate, max_sec=args.max)
    else:
        write_mssiah_wav(audio, out_name, max_sec=args.max)


if __name__ == "__main__":
    main()
