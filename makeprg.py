#!/usr/bin/env python3
# makeprg.py
# v0.11

import sys
import os
import argparse

# Rough safety limit so we don't overshadow C64 memory.
MAX_PRG_SIZE = 40000

# Default minimal pre-assembled player file you want to merge with.
# This must have a 2-byte load address and the code that references
# the label where the sample is appended.
# some examples include:
#   PLAYER_BIN = "./prg/loopplay.prg"
#   PLAYER_BIN = "./prg/loopplay_16k.prg"
#   PLAYER_BIN = "./prg/loopplay_32k.prg"
#   PLAYER_BIN = "./prg/loopplay_64k.prg"
PLAYER_BIN = "./prg/loopplay_dualnibbles.prg"
# Uncomment this line if your default preference is single nibble:
# PLAYER_BIN = "./prg/loopplay_singleNibble.prg"

def main():
    parser = argparse.ArgumentParser(
        description="Merge a 4-bit .raw sample with a minimal C64 player .prg, producing a single .prg."
    )

    parser.add_argument(
        "input_raw",
        help="Path to input .raw (4-bit) file to be appended."
    )
    parser.add_argument(
        "output_prg",
        nargs="?",
        help="Optional output .prg filename (defaults to input filename + .prg)."
    )

    # Accept both --dualnibble and --dualnibbles as synonyms
    parser.add_argument(
        "--dualnibble", "--dualnibbles",
        action="store_true",
        help="Use the dual-nibbles player (./prg/loopplay_dualnibbles.prg)."
    )
    # Accept both --singlenibble and --singlenibbles as synonyms
    parser.add_argument(
        "--singlenibble", "--singlenibbles",
        action="store_true",
        help="Use the single-nibble player (./prg/loopplay_singleNibble.prg)."
    )

    args = parser.parse_args()

    # Start with the default from the top of this file:
    player_bin = PLAYER_BIN

    # If the user requested a specific mode, override:
    if args.dualnibble and args.singlenibble:
        print("ERROR: Cannot combine both dual-nibble and single-nibble modes.")
        sys.exit(1)
    elif args.dualnibble:
        player_bin = "./prg/loopplay_dualnibbles.prg"
    elif args.singlenibble:
        player_bin = "./prg/loopplay_singleNibble.prg"

    # Name the input and output files
    input_raw = args.input_raw
    output_prg = args.output_prg

    # Verify .raw file exists
    if not os.path.isfile(input_raw):
        print(f"ERROR: cannot find input file '{input_raw}'")
        sys.exit(1)

    # If user gave no output name, derive from the input
    if not output_prg:
        base, _ = os.path.splitext(input_raw)
        output_prg = base + ".prg"

    # Check for the minimal player
    if not os.path.isfile(player_bin):
        print(f"ERROR: cannot find player '{player_bin}'")
        sys.exit(1)

    # Read the player code (already includes 2-byte load address, e.g. $0801)
    with open(player_bin, "rb") as f:
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

    # Calculate total size
    combined_size = len(player_data) + len(sample_data)
    if combined_size > MAX_PRG_SIZE:
        print(f"ERROR: Combined .prg would be {combined_size} bytes, exceeding limit of {MAX_PRG_SIZE}.")
        print("Refusing to merge. Consider shorter audio or a 2-file disk load approach.")
        sys.exit(1)

    # Merge the player code + sample data
    final_data = player_data + sample_data

    # Write out as a single .prg
    with open(output_prg, "wb") as f:
        f.write(final_data)

    print(f"[OK] Wrote '{output_prg}' ({combined_size} bytes).")
    print(f"Used player: {player_bin}")

if __name__ == "__main__":
    main()
