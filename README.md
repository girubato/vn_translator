# VN Translator

Real-time Japanese OCR and translation for visual novels on Linux. Captures a region of your screen, extracts Japanese text using MeikiOCR, translates it to English, and displays the results in your terminal and a web interface.

The web interface is designed for use with [Yomitan](https://github.com/yomidevs/yomitan) - you can hover over the Japanese text to look up words.

## Requirements

- Linux with X11
- Python 3
- System packages: `slop`, `maim`, `xdotool`, `translate-shell`

## Installation

1. Install system dependencies:
   ```bash
   sudo apt install slop maim xdotool python3 python3-pip python3-venv translate-shell
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/girubato/vn_translator.git
   cd vn_translator
   ```

3. Set up Python virtual environment and install packages:
   ```bash
   python3 -m venv ~/vn-translator-env
   source ~/vn-translator-env/bin/activate
   pip install meikiocr opencv-python numpy
   ```

## Usage

1. Start the translator:
   ```bash
   ./vn_translator.sh
   ```

2. On first run, you'll be prompted to select a screen region. Click and drag to select the text box area in your visual novel.

3. The translator will now monitor that region. When text changes, it will:
   - Extract the Japanese text
   - Translate it to English
   - Display both in the terminal
   - Serve the text at http://localhost:8765

4. Press `Ctrl+C` to stop.

### Other Commands

```bash
./vn_translator.sh set-region    # Select a new screen region
./vn_translator.sh start         # Run in background
./vn_translator.sh stop          # Stop background services
./vn_translator.sh status        # Check if running
./vn_translator.sh clear-history # Clear translation history
```

### Configuration

Environment variables:
- `VN_POLL_INTERVAL` - Seconds between screen captures (default: 0.5)
- `VN_SIMILARITY_THRESHOLD` - How similar text must be to skip re-translation, 0.0-1.0 (default: 0.85)

Example with lower CPU usage:
```bash
VN_POLL_INTERVAL=1.0 ./vn_translator.sh
```

## Files

Config and logs are stored in `~/.vn_translator/`:
- `region.conf` - Selected screen region
- `last_text.txt` - Current Japanese text
- `last_translation.txt` - Current English translation
- `history.log` - All translations with timestamps
