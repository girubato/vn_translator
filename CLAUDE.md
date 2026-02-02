# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VN Translator is a real-time Japanese OCR and translation system for visual novels. It captures a screen region, extracts Japanese text using MeikiOCR, translates it via translate-shell, and displays results both in terminal and a web interface designed for Yomitan dictionary integration.

## Architecture

Three components work together:

1. **`vn_translator_meikiocr_v10.sh`** - Main OCR monitoring loop
   - Captures screen region using `maim`
   - Calls `meikiocr_helper.py` for OCR
   - Translates via `trans` (translate-shell)
   - Writes results to `~/.vn_translator/` files

2. **`meikiocr_helper.py`** - OCR wrapper
   - Takes image path as argument
   - Uses OpenCV to read image, MeikiOCR for text extraction
   - Outputs Japanese text to stdout

3. **`vn_translator_webserver_v10.py`** - Web server (port 8765)
   - `GET /` - HTML dashboard with live updates
   - `GET /api/text` - JSON endpoint (`{text, translation, timestamp}`)
   - Reads from `~/.vn_translator/last_text.txt` and `last_translation.txt`

## Commands

```bash
# Setup virtual environment (first time)
python3 -m venv ~/vn-translator-env
source ~/vn-translator-env/bin/activate
pip install meikiocr opencv-python numpy

# Select screen region
./vn_translator_meikiocr_v10.sh set-region

# Start OCR monitoring
./vn_translator_meikiocr_v10.sh monitor

# Test single capture with debug output
./vn_translator_meikiocr_v10.sh test

# Start web server (separate terminal)
python3 vn_translator_webserver_v10.py
```

## Configuration

- **Config directory**: `~/.vn_translator/`
- **`region.conf`**: Selected screen region (format: `WIDTHxHEIGHT+X+Y`)
- **`last_text.txt`**: Current OCR'd Japanese text
- **`last_translation.txt`**: Current English translation
- **`VN_POLL_INTERVAL`**: Environment variable for polling interval (default: 0.5s)

## System Dependencies

```bash
sudo apt install slop maim xdotool python3 python3-pip translate-shell
```

## Python Dependencies

- meikiocr (ONNX-based Japanese OCR)
- opencv-python
- numpy
