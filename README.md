# audio-bitsqueezer

**audio-bitsqueezer** (or just **bitsqueezer**) is a Python utility that converts modern audio files (MP3, WAV, FLAC, etc.) into:
1. **Raw 4-bit nibble data** -- great for old-school tricks on machines like the Commodore 64 (volume-register "digis").
2. **MSSIAH-compatible 8-bit WAV** at 6 kHz -- the perfect output format if you're using the Commodore 64 [MSSIAH](https://mssiah.com/) cartridge.

## How It Works

- **Decode**: Uses [FFmpeg](https://ffmpeg.org/) via [pydub](https://github.com/jiaaro/pydub) to handle nearly any input format, starting from (but not limited to) MP3, WAV, AIFF, FLAC, etc.  
- **Downmix**: Automatically converts multi-channel audio to mono.  
- **Resample**: Choose a sample rate (default is 8000 Hz for 4-bit mode; forced 6 kHz in MSSIAH mode).  
- **Quantize & Pack** (4-bit mode): Maps 16-bit samples to 4 bits (0–15), then packs two samples into each byte for raw nibble data.  
- **8-bit MSSIAH Mode**: Forces the audio to 6 kHz, 8-bit mono WAV. You can rename it on disk (e.g., `MYFILE    .WAV.PRG`) and load directly into MSSIAH Wave-Player.  
- **Write**: Outputs either `.raw` (for 4-bit nibble data) or `.wav` (for MSSIAH).  

**NOTE:** Keep your audio samples short; i.e. MSSIAH, according to its [manual](https://mssiah.com/files/MSSIAH_WavePlayer.pdf), accepts a maximum of approx. 5.5sec long samples.

## Requirements

- **Python 3.6+** (older versions *might* work; no guarantees though).  
- [**FFmpeg**](https://ffmpeg.org/download.html) installed and on your PATH.  
  - Linux (Debian/Ubuntu): `sudo apt-get install ffmpeg`  
  - macOS: `brew install ffmpeg`  
  - Windows: Download from [ffmpeg.org](https://ffmpeg.org/) and ensure `ffmpeg.exe` is in your PATH.  
- **pydub** library  
  ```bash
  pip install pydub
  ```

## Installation

```bash
git clone https://github.com/FlyingFathead/audio-bitsqueezer.git
cd audio-bitsqueezer
pip install pydub
```

**NOTE:** Make sure FFmpeg is installed and accessible. this program will not work without it.

## Usage

```
python bitsqueezer.py <infile> [--mode 4bit|mssiah] [--rate SAMPLE_RATE] [--out OUTPUT_FILE]
```

### Modes

1. **4bit**: Creates raw 4-bit nibble data.  
2. **mssiah**: Creates an 8-bit, 6 kHz WAV suitable for MSSIAH Wave-Player disk import.

### Examples

1. **Default 4-bit** (no `--out`, rate=8000 Hz):
   ```bash
   python bitsqueezer.py my_audio.wav --mode 4bit
   ```
   - Outputs `my_audio_4bit_8000hz.raw`.

2. **Specify a sample rate** (still 4bit):
   ```bash
   python bitsqueezer.py my_audio.mp3 --mode 4bit --rate 11025
   ```
   - Outputs `my_audio_4bit_11025hz.raw`.

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
- **MSSIAH `.wav`**: Rename to the MSSIAH-required `.WAV.PRG` format, put it on disk (or Savyour/USB), and import it into the MSSIAH Wave-Player.

## 4-Bit Raw Output Details

- **Samples**: Each sample is 4 bits (0–15).  
- **Two samples/byte**: Low nibble is first, high nibble is second.  
- **No header**: It’s plain data. You must track the sample rate yourself.

## Testing on PC

If you try to play the **4-bit `.raw`** file directly on your modern computer (e.g., using `aplay`, `ffplay`, or another raw PCM player), you may notice the audio sounds **twice as fast** (i.e., higher-pitched). This is because each byte in the 4-bit file actually holds **two** samples (the low nibble and the high nibble). Standard PCM players assume “one sample per byte,” so they race through the data at double speed.

### Quick Workaround

You can lower the playback rate to half in your player so each byte lasts twice as long. For example, if you originally targeted **8000 Hz** with bitsqueezer, try:

   ```bash
   aplay -f U8 -r 4000 -c 1 my_audio_4bit_8000hz.raw
   ```

This “slows down” playback to the correct pitch (albeit still interpreting 4-bit data as if it’s 8-bit amplitude, which might sound crunchy or quiet).

### Proper Approach

If you need a more faithful preview, you must **unpack** the 4-bit file into a standard 8-bit or 16-bit PCM file first. That involves:

1. Reading each byte.  
2. Extracting the lower nibble (bits 0–3) and the higher nibble (bits 4–7).  
3. Mapping each nibble to an 8-bit range (e.g., multiplying by 16 if you want 0..15 to become 0..240).  
4. Writing out two bytes (or two 8-bit samples) per original byte.

Once you’ve done this unpacking, you can play the resulting full 8-bit PCM file at the **original** sample rate (e.g., 8000 Hz) without pitch issues. This doesn’t add any fidelity (it’s still 4-bit data at heart), but it helps standard players recognize one sample per byte.

If you’re ultimately loading this file on a Commodore 64 (or other retro device) for volume-register playback, none of this matters—because your own code will (hopefully) already be reading each nibble from each byte properly at the correct rate. This is purely a convenience for quick testing on a modern computer.

## FAQ

### Why 4 bits?
Some retro hardware (Commodore 64, etc.) can’t do real 8-bit PCM easily. Tricks using the SID’s volume register only allow ~4 bits of resolution. In many use cases, **bitsqueezer** handles that conversion for you.

You can also use it to pre-process your audio to be used with the [MSSIAH](https://mssiah.com/) cartridge for the Commodore 64. See the MSSIAH cartridge [Wave-Player manual](https://mssiah.com/files/MSSIAH_WavePlayer.pdf) for more info.

### Will it sound great?
That's completely subjective. Nonetheless, welcome to the "high fidelity" of 4-bit audio. You wanted retro, you got retro. No refunds!

### Why MSSIAH mode?
**It's just a bonus feature.** You don't necessarily _need_ a MSSIAH hardware cartridge to transfer the audio data to (i.e.) your Commodore 64, but if you're using a MSSIAH cartridge, it can help in that.

The MSSIAH cartridge is a great tool if you're using original C64 hardware as its data-over-MIDI functionality is extremely well-suited for creating C64 "digis". 

MSSIAH's Wave-Player requires 8-bit/6 kHz WAV on import when using data over MIDI. The MSSIAH mode in bitsqueezer will help you in that.

MSSIAH handles further processing to suit its compatibility internally, so the 4-bit squeeze step isn't required in MSSIAH use.

For more information on the MSSIAH mode, please see i.e. [MSSIAH Wave-Player Manual (PDF)](https://mssiah.com/files/MSSIAH_WavePlayer.pdf) or the [C64 MSSIAH Cartridge](https://mssiah.com/) website.

## License

At least for now, use it for whatever. If you adapt it somewhere, a quick nod back here to [**FlyingFathead/bitsqueezer**](https://github.com/FlyingFathead/audio-bitsqueezer) would be nice.

**Note:** I'm in no way affiliated with the MSSIAH cartridge or any of their other hardware projects. Please refer to their manuals and customer support if you have any issues with your MSSIAH hardware.

## Contributing & Contact

Pull requests, bug reports, and suggestions welcome. If you want advanced dithering, different sample packing, or feature expansions, open an issue or PR.

You can contact me via email from `flyingfathead@protonmail.com` or on Twitter/X: [@horsperg](https://x.com/horsperg)

---

_**Enjoy the squeeze!**_
