#!/usr/bin/env python3
# makeprg.py
import sys
import os

# Rough safety limit so we don't overshadow C64 memory.
MAX_PRG_SIZE = 40000

# The minimal pre-assembled player file you want to merge with.
# This file must have a 2-byte load address and the code that
# references the label where the sample is appended.
# PLAYER_BIN = "player.bin"
PLAYER_BIN = "./prg/holy_sample.prg"

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input_4bit.raw> [output.prg]")
        sys.exit(1)

    input_raw = sys.argv[1]
    if not os.path.isfile(input_raw):
        print(f"ERROR: cannot find input file '{input_raw}'")
        sys.exit(1)

    # If user gave an explicit output name, use it; else base it on input name
    if len(sys.argv) > 2:
        output_prg = sys.argv[2]
    else:
        base, _ = os.path.splitext(input_raw)
        output_prg = base + ".prg"

    # Check for the minimal player
    if not os.path.isfile(PLAYER_BIN):
        print(f"ERROR: cannot find '{PLAYER_BIN}'")
        sys.exit(1)

    # Read the player code (already includes 2-byte load address, e.g. $0801)
    with open(PLAYER_BIN, "rb") as f:
        player_data = f.read()

    # Read the raw 4-bit sample data
    with open(input_raw, "rb") as f:
        sample_data = f.read()

    # Add a sentinel 0 => ensures we don't read 0 as first sample unless it truly is.
    if len(sample_data) > 0:
        # only if there's data
        sample_data += b"\x00"
    else:
        print("WARNING: .raw file is empty, will stop playback immediately")

    # final_data = player_data + sample_data

    # Quick size check
    combined_size = len(player_data) + len(sample_data)
    if combined_size > MAX_PRG_SIZE:
        print(f"ERROR: Combined .prg would be {combined_size} bytes, exceeding limit of {MAX_PRG_SIZE}.")
        print("Refusing to merge. Consider shorter audio or a 2-file disk load approach.")
        sys.exit(1)

    # Merge the player code + sample data
    final_data = player_data + sample_data

    # Write out as a single PRG
    with open(output_prg, "wb") as f:
        f.write(final_data)

    print(f"[OK] Wrote '{output_prg}' ({combined_size} bytes).")

if __name__ == "__main__":
    main()
