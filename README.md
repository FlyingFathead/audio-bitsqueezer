# audio-bitsqueezer

**audio-bitsqueezer** (or just **bitsqueezer**) is a Python utility that converts modern audio files (MP3, WAV, FLAC, etc.) into:

1. **Raw 4-bit nibble data** — great for old-school tricks on machines like the Commodore 64 (volume-register “digis”).  
2. **MSSIAH-compatible 8-bit WAV** at 6 kHz — the perfect output format if you're using the Commodore 64 [MSSIAH](https://mssiah.com/) cartridge.
3. **A complete `.prg`** — by merging the 4-bit `.raw` output with a minimal player via `maketoprg.py`, so you can run it directly on the C64 or an emulator, using its audio output.

## How It Works

- **Decode**: Uses [FFmpeg](https://ffmpeg.org/) via [pydub](https://github.com/jiaaro/pydub) to handle nearly any input format (MP3, WAV, AIFF, FLAC, etc.).  
- **Downmix**: Automatically converts multi-channel audio to mono.  
- **Resample**: Choose a sample rate (default is **4000 Hz** for 4-bit mode; forced **6 kHz** in MSSIAH mode).  
- **Quantize & Pack** (4-bit mode): Maps 16-bit samples to 4 bits (0–15), then packs two samples into each byte for raw nibble data.  
- **8-bit MSSIAH Mode**: Forces the audio to 6 kHz, 8-bit mono WAV. You can rename it on disk (e.g., `MYFILE    .WAV.PRG`) and load directly into MSSIAH Wave-Player.  
- **Write**: Outputs either `.raw` (for 4-bit nibble data) or `.wav` (for MSSIAH).

---

- **(Optional)** Merge 4-bit data with a minimal player using **`maketoprg.py`**, yielding a self-contained `.prg` that can be `LOAD`ed and `RUN` on a real Commodore 64 (or emulator).

---

**NOTE:** Keep your audio samples short. The MSSIAH Wave-Player routine can typically handle ~5.5 seconds max. Longer than that may not fit in memory.

## Requirements

- **Python 3.6+**  
- [**FFmpeg**](https://ffmpeg.org/download.html) installed and on your PATH.  
  - Linux (Debian/Ubuntu): `sudo apt-get install ffmpeg`  
  - macOS: `brew install ffmpeg`  
  - Windows: Download from [ffmpeg.org](https://ffmpeg.org/) and ensure `ffmpeg.exe` is on your PATH.  
- **pydub** library:  
  ```bash
  pip install pydub
  ```
If you wish to use the `maketoprg.py`and run it somewhere, you'll either need i.e. [VICE C64 Emulator](https://vice-emu.sourceforge.io/) or an actual Commodore 64.

## Installation

```bash
git clone https://github.com/FlyingFathead/audio-bitsqueezer.git
cd audio-bitsqueezer
pip install pydub
```
Make sure FFmpeg is installed and accessible. Otherwise, bitsqueezer won’t function.

## Usage

```
python bitsqueezer.py <infile> [--mode 4bit|mssiah] [--rate SAMPLE_RATE] [--out OUTPUT_FILE]
```

### Modes

1. **4bit**: Creates raw 4-bit nibble data.  
2. **mssiah**: Creates an 8-bit, 6 kHz WAV suitable for MSSIAH Wave-Player disk import.

### Examples

1. **Default 4-bit** (no `--out`, rate = **4000 Hz**):
   ```bash
   python bitsqueezer.py my_audio.wav --mode 4bit
   ```
   - Outputs `my_audio_4bit_4000hz.raw`.

2. **Specify a different sample rate** (still 4-bit):
   ```bash
   python bitsqueezer.py my_audio.mp3 --mode 4bit --rate 8000
   ```
   - Outputs `my_audio_4bit_8000hz.raw`.

3. **MSSIAH mode** (6 kHz, 8-bit WAV):
   ```bash
   python bitsqueezer.py my_audio.flac --mode mssiah
   ```
   - Outputs `my_audio_mssiah_6khz.wav`.

4. **Fully specify output**:
   ```bash
   python bitsqueezer.py input.wav --mode mssiah --out final_mssiah.wav
   ```
   - Writes an 8-bit, 6 kHz WAV to `final_mssiah.wav`.

Once you have your file:
- **4-bit `.raw`**: Ideal for direct volume-register playback on retro hardware.  
- **MSSIAH `.wav`**: Rename to the MSSIAH-required `.WAV.PRG` format, place it on disk (or Savyour/USB), and import it into MSSIAH Wave-Player.

## Creating a Self-Running `.prg` on the C64

After you’ve produced a **4-bit `.raw`** file, you can merge it with one of the minimal C64 “player” binaries included in the **asm/** folder. This merging is done via **`makeprg.py`**, which:

1. Reads the existing “player” `.prg` file (which already has a 2-byte load address and references a label for appended sample data).  
2. Appends your `.raw` data plus a trailing sentinel `0x00`.  
3. Writes out a single `.prg` that you can load and run on the C64.

Usage example:
```bash
# Adjust the `PLAYER_BIN` variable inside makeprg.py to point to
# the minimal player code you want, e.g. `loopplay.prg` or `loopplay_cia1_irq_16k.prg`.

# Then run:
python makeprg.py my_audio_4bit_4000hz.raw final.prg

# "final.prg" is a complete, executable file for the C64 that
# auto-plays your 4-bit sample data.
```

If you have multiple pre-assembled players (e.g. a 4 kHz vs. 8 kHz vs. 16 kHz version), you can pick which `.prg` to merge your raw data with by editing the `PLAYER_BIN` path near the top of `makeprg.py`.

## 4-Bit Raw Output Details

- **Samples**: Each sample is 4 bits (0–15).  
- **Two samples per byte**: Low nibble first, then high nibble.  
- **No header**: Just raw amplitude data.  

**Default rate** is **4000 Hz**. If you want a faster or higher-pitched playback, pass a higher `--rate` (like 8000 or 11025). Bear in mind the C64 routine must match your intended rate.

## Testing on a Modern PC

If you attempt to directly play the `.raw` file (e.g., with `aplay` or `ffplay`), it will likely:
- Sound half as long (since each byte has 2 × 4-bit samples).  
- Sound “quiet” or “distorted,” because typical PCM players expect 8 bits per sample.  

### Quick Workaround

Lower the playback rate by half; for example, if bitsqueezer used **4000 Hz**:
```bash
aplay -f U8 -r 2000 -c 1 my_audio_4bit_4000hz.raw
```
This forces the data to play at half speed in bytes, matching the correct pitch. Not perfect, but quick.

### Proper Approach

To preview more accurately, **unpack** each 4-bit nibble to a standard 8-bit or 16-bit PCM file:
1. Read each byte, separate into a low nibble (bits 0–3) and a high nibble (bits 4–7).  
2. Map those nibbles to, e.g., 8-bit range (multiply by 16).  
3. Write them out as two consecutive 8-bit samples.  
4. Play that new file at the original 4 kHz rate.  

On a real C64, your playback routine is responsible for reading those nibbles at the correct speed, so no special “unpacking” is needed.

## FAQ

### Why 4 bits?

The C64’s SID volume register trick can’t easily generate true 8-bit PCM. This yields ~4 bits.  **bitsqueezer** automates that conversion for easy retro-audio playback.

### Will It Sound “Good”?

Well... welcome to the crunchy world of 4-bit audio.

### MSSIAH Mode

MSSIAH’s Wave-Player expects an 8-bit, 6 kHz WAV. If you’re using MSSIAH, select `--mode mssiah`. You do not need MSSIAH hardware for normal 4-bit usage though.

## License

Use freely. If you adapt it, a nod to [**FlyingFathead/bitsqueezer**](https://github.com/FlyingFathead/audio-bitsqueezer) is appreciated.

(*Not affiliated with MSSIAH or its creators.*)

## Contributing & Contact

Pull requests, bug reports, suggestions welcome.  

Email: `flyingfathead@protonmail.com`  
Twitter/X: [@horsperg](https://x.com/horsperg)

**_Enjoy the squeeze_!**