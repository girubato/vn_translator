# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VN Translator is a real-time Japanese OCR and translation system for visual novels. It captures a screen region, extracts Japanese text using MeikiOCR, translates it via translate-shell, and displays results both in terminal and a web interface designed for Yomitan dictionary integration.

## Architecture

**`vn_translator.sh`** - Unified launcher that manages all services (start/stop/status).

Core components:

1. **`vn_translator_meikiocr_v10.sh`** - Main OCR monitoring loop
   - Captures screen region using `maim`
   - Calls `meikiocr_helper.py` for OCR
   - Uses `similarity_check.py` for fuzzy text matching (avoids re-translating similar lines)
   - Translates via `trans` (translate-shell)
   - Writes results to `~/.vn_translator/` files and appends to `history.log`

2. **`meikiocr_helper.py`** - OCR wrapper
   - Takes image path as argument
   - Uses OpenCV to read image, MeikiOCR for text extraction
   - Outputs Japanese text to stdout

3. **`vn_translator_webserver_v10.py`** - Web server (port 8765)
   - `GET /` - HTML dashboard with live updates
   - `GET /api/text` - JSON endpoint (`{text, translation, timestamp}`)
   - Reads from `~/.vn_translator/last_text.txt` and `last_translation.txt`

4. **`similarity_check.py`** - Fuzzy text comparison
   - Compares two strings using difflib
   - Returns exit 0 if similar (skip), exit 1 if different (process)

## Commands

```bash
# Setup virtual environment (first time)
python3 -m venv ~/vn-translator-env
source ~/vn-translator-env/bin/activate
pip install meikiocr opencv-python numpy

# Unified launcher (recommended)
./vn_translator.sh              # Run in foreground (Ctrl+C to stop)
./vn_translator.sh start        # Run in background
./vn_translator.sh stop         # Stop background services
./vn_translator.sh status       # Check service status
./vn_translator.sh set-region   # Select screen region

# Individual components (if needed)
./vn_translator_meikiocr_v10.sh test    # Single capture test with debug
python3 vn_translator_webserver_v10.py  # Web server only
```

## Configuration

- **Config directory**: `~/.vn_translator/`
- **`region.conf`**: Selected screen region (format: `WIDTHxHEIGHT+X+Y`)
- **`last_text.txt`**: Current OCR'd Japanese text
- **`last_translation.txt`**: Current English translation
- **`history.log`**: Translation history with timestamps
- **`VN_POLL_INTERVAL`**: Polling interval in seconds (default: 0.5)
- **`VN_SIMILARITY_THRESHOLD`**: Fuzzy match threshold 0.0-1.0 (default: 0.85) - higher values skip more similar lines

## System Dependencies

```bash
sudo apt install slop maim xdotool python3 python3-pip translate-shell
```

## Python Dependencies

- meikiocr (ONNX-based Japanese OCR)
- opencv-python
- numpy
