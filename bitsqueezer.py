#!/usr/bin/env python3
"""
bitsqueezer.py
==============
(Official repository at: https://github.com/FlyingFathead/bitsqueezer)

All-in-one tool that:
1) Reads any audio file format supported by FFmpeg (via pydub).
2) Downmixes to mono.
3) Resamples to desired rate.
4) Either:
    - 4-bit raw nibble output (for direct volume-register playback).
    - 8-bit WAV at 6 kHz (for MSSIAH Wave-Player disk import).

Also warns if the final audio exceeds a user-set "max duration" 
(default ~5.5 s) for MSSIAH memory constraints.

Usage examples:
---------------
    # Produce a 4-bit raw file at default 8000 Hz:
    python bitsqueezer.py input.wav --mode 4bit

    # Same, but specify sample rate = 11025
    python bitsqueezer.py input.wav --mode 4bit --rate 11025

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

def check_ffmpeg_installed():
    """
    Check if 'ffmpeg' is accessible on the system PATH.
    Exits if not found or if calling `ffmpeg -version` fails.
    """
    try:
        # Attempt to run `ffmpeg -version` and capture output
        proc = subprocess.run(
            ["ffmpeg", "-version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True  # Raises CalledProcessError on non-zero return
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

def write_4bit_raw(audio, out_filename, sample_rate, max_sec=9999.0):
    """
    Convert 'audio' (a pydub AudioSegment) to 4-bit raw nibble data, 
    pack 2 nibbles/byte, write to out_filename.
    """
    # 1) Ensure mono
    if audio.channels != 1:
        audio = audio.set_channels(1)
    # 2) Resample
    if audio.frame_rate != sample_rate:
        audio = audio.set_frame_rate(sample_rate)

    # Warn about length if desired
    warn_if_too_long(audio.duration_seconds, max_sec=max_sec)

    # 3) Convert to 16-bit
    audio = audio.set_sample_width(2)  # 16-bit
    raw_samples = audio.raw_data
    num_samples = len(raw_samples) // 2  # 2 bytes per sample

    samples = struct.unpack("<" + "h" * num_samples, raw_samples)

    # 4) Quantize to 4 bits
    nibbles = []
    for s in samples:
        # clamp
        if s < -32768: s = -32768
        elif s > 32767: s = 32767
        shifted = s + 32768  # [0..65535]
        val_4bit = (shifted >> 12) & 0x0F  # [0..15]
        nibbles.append(val_4bit)

    # 5) Pack 2 nibbles per byte
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
    We'll also warn if it's > 5.5s.

    Then you can rename it to something like: 'MYFILE    .WAV.PRG' 
    (16 chars plus .WAV) for actual C64 disk usage.
    """
    # 1) Force mono
    if audio.channels != 1:
        audio = audio.set_channels(1)
    # 2) Force 6 kHz
    if audio.frame_rate != 6000:
        audio = audio.set_frame_rate(6000)
    # 3) Force 8-bit
    audio = audio.set_sample_width(1)  # 8-bit

    # Warn about length
    warn_if_too_long(audio.duration_seconds, max_sec=max_sec)

    # 4) Export as WAV (pydub can do that directly)
    audio.export(out_filename, format="wav")
    print(f"[MSSIAH WAV] {out_filename} written.")
    print(f"    8-bit, 6 kHz, mono, duration ~{audio.duration_seconds:.2f}s")

def main():

    check_ffmpeg_installed()  # <--- Check for ffmpeg first!

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

    args = parser.parse_args()

    # Prepare output file name if not provided
    if not args.out:
        base, ext = os.path.splitext(args.infile)
        if args.mode == "4bit":
            out_name = f"{base}_4bit_{args.rate}hz.raw"
        else:
            # mssiah mode
            out_name = f"{base}_mssiah_6khz.wav"
    else:
        out_name = args.out

    # Load input
    try:
        audio = AudioSegment.from_file(args.infile)
    except Exception as e:
        print(f"ERROR reading input file: {e}")
        sys.exit(1)

    if args.mode == "4bit":
        # do the 4bit conversion
        write_4bit_raw(audio, out_name, sample_rate=args.rate, max_sec=args.max)
    else:
        # do the 6 kHz, 8-bit WAV for MSSIAH
        write_mssiah_wav(audio, out_name, max_sec=args.max)

if __name__ == "__main__":
    main()

