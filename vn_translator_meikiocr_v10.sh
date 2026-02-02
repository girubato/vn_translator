#!/bin/bash

# VN Real-Time OCR + Translation
# Japanese -> English with live monitoring
#
# Version using MeikiOCR for improved accuracy

CONFIG_DIR="$HOME/.vn_translator"
REGION_FILE="$CONFIG_DIR/region.conf"
LAST_TEXT_FILE="$CONFIG_DIR/last_text.txt"
LAST_TRANSLATION_FILE="$CONFIG_DIR/last_translation.txt"
HISTORY_FILE="$CONFIG_DIR/history.log"
TEMP_IMAGE="/tmp/vn_translator_capture.png"

# Similarity threshold (0.0-1.0) - texts above this are considered "same"
SIMILARITY_THRESHOLD=${VN_SIMILARITY_THRESHOLD:-0.85}

# Polling interval in seconds
POLL_INTERVAL=${VN_POLL_INTERVAL:-0.5}

mkdir -p "$CONFIG_DIR"

# Path to the Python helper scripts (adjust as needed)
SCRIPT_DIR="$(dirname "$0")"
MEIKIOCR_HELPER="$SCRIPT_DIR/meikiocr_helper.py"
SIMILARITY_CHECKER="$SCRIPT_DIR/similarity_check.py"

# Virtual environment path (adjust if you created it elsewhere)
VENV_PATH="$HOME/vn-translator-env"

# --- Dependency Check ---

# Check dependencies
check_deps() {
    local missing=()
    for cmd in slop maim xdotool python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt install slop maim xdotool python3 python3-pip"
        exit 1
    fi
    
    # Check for helper scripts
    if [ ! -f "$MEIKIOCR_HELPER" ]; then
        echo "Error: MeikiOCR helper script not found at: $MEIKIOCR_HELPER"
        echo "Please ensure meikiocr_helper.py is in the same directory as this script"
        exit 1
    fi

    if [ ! -f "$SIMILARITY_CHECKER" ]; then
        echo "Error: Similarity checker not found at: $SIMILARITY_CHECKER"
        echo "Please ensure similarity_check.py is in the same directory as this script"
        exit 1
    fi
    
    # Check for MeikiOCR Python package
    if [ -d "$VENV_PATH" ]; then
        # Use virtual environment
        PYTHON_CMD="$VENV_PATH/bin/python3"
        if ! "$PYTHON_CMD" -c "import meikiocr" 2>/dev/null; then
            echo "MeikiOCR not found in virtual environment"
            echo "Run: source $VENV_PATH/bin/activate && pip install meikiocr opencv-python numpy"
            exit 1
        fi
    else
        # Try system Python
        PYTHON_CMD="python3"
        if ! python3 -c "import meikiocr" 2>/dev/null; then
            echo "MeikiOCR not found"
            echo ""
            echo "Option 1 - Use virtual environment (recommended):"
            echo "  python3 -m venv ~/vn-translator-env"
            echo "  source ~/vn-translator-env/bin/activate"
            echo "  pip install meikiocr opencv-python numpy"
            echo ""
            echo "Option 2 - Use pipx:"
            echo "  sudo apt install pipx"
            echo "  pipx install meikiocr --include-deps"
            echo ""
            echo "Option 3 - Override (not recommended):"
            echo "  pip install --break-system-packages meikiocr opencv-python numpy"
            exit 1
        fi
    fi
    
    # Check for translation tool
    if ! command -v trans >/dev/null 2>&1; then
        echo "translate-shell not found"
        echo "Install: sudo apt install translate-shell"
        echo "Or: wget git.io/trans && chmod +x trans && sudo mv trans /usr/local/bin/"
        exit 1
    fi
}

# Set capture region
set_region() {
    echo "Select the text box region..."
    REGION=$(slop -f "%wx%h+%x+%y")
    
    if [ -z "$REGION" ]; then
        echo "No region selected"
        exit 1
    fi
    
    echo "REGION=\"$REGION\"" > "$REGION_FILE"
    echo "Region set: $REGION"
}

# Clean OCR text
clean_japanese_text() {
    local text="$1"
    
    # Remove common OCR artifacts
    text=$(echo "$text" | tr -d '\n\r' | sed 's/  */ /g')
    
    # Remove standalone English letters/numbers that are likely artifacts
    # But keep them if they're part of Japanese text
    text=$(echo "$text" | sed 's/^ *//;s/ *$//')
    
    # Skip if too short or likely garbage
    local char_count=$(echo "$text" | wc -m)
    if [ "$char_count" -lt 3 ]; then
        return 1
    fi
    
    echo "$text"
    return 0
}

# Translate text
translate_text() {
    local japanese="$1"
    local translation
    
    # Use translate-shell with timeout
    translation=$(timeout 5s trans -b ja:en "$japanese" 2>/dev/null)
    
    if [ -z "$translation" ] || [[ "$translation" == *"Could not"* ]]; then
        return 1
    fi
    
    echo "$translation"
    return 0
}

# Display translation output
display_output() {
    local japanese="$1"
    local english="$2"
    
    echo ""
    echo "Japanese: $japanese"
    echo "English:  $english"
    echo "----------------------------------------"
}

# Monitor and translate
monitor_region() {
    if [ ! -f "$REGION_FILE" ]; then
        echo "No region set. Run: $0 set-region"
        exit 1
    fi
    
    source "$REGION_FILE"
    
    if [ -z "$REGION" ]; then
        echo "Invalid region"
        exit 1
    fi
    
    echo "Monitoring region: $REGION"
    echo "Using MeikiOCR for Japanese text recognition..."
    echo "Polling interval: ${POLL_INTERVAL}s (set VN_POLL_INTERVAL to change)"
    echo "Similarity threshold: ${SIMILARITY_THRESHOLD} (set VN_SIMILARITY_THRESHOLD to change)"
    echo "History log: $HISTORY_FILE"
    echo "Press Ctrl+C to stop"
    echo "========================================"
    
    # Initialize last text
    touch "$LAST_TEXT_FILE"
    
    while true; do
        # Capture screenshot with maim and save to temp file
        maim -g "$REGION" -u "$TEMP_IMAGE" 2>/dev/null
        
        if [ ! -f "$TEMP_IMAGE" ]; then
            sleep 0.5
            continue
        fi
        
        # Run MeikiOCR via Python helper
        TEXT=$(${PYTHON_CMD:-python3} "$MEIKIOCR_HELPER" "$TEMP_IMAGE" 2>/dev/null)
        
        # Clean the text
        CLEAN_TEXT=$(clean_japanese_text "$TEXT")
        
        if [ $? -eq 0 ] && [ -n "$CLEAN_TEXT" ]; then
            # Check if text changed (using fuzzy matching)
            LAST_TEXT=$(cat "$LAST_TEXT_FILE" 2>/dev/null)

            # Use similarity check - exit 0 means similar (skip), exit 1 means different (process)
            if [ -z "$LAST_TEXT" ] || ! ${PYTHON_CMD:-python3} "$SIMILARITY_CHECKER" "$CLEAN_TEXT" "$LAST_TEXT" "$SIMILARITY_THRESHOLD"; then
                # Save current text
                echo "$CLEAN_TEXT" > "$LAST_TEXT_FILE"

                # Translate
                TRANSLATION=$(translate_text "$CLEAN_TEXT")

                if [ $? -eq 0 ]; then
                    # Save translation
                    echo "$TRANSLATION" > "$LAST_TRANSLATION_FILE"
                    display_output "$CLEAN_TEXT" "$TRANSLATION"

                    # Append to history log
                    {
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
                        echo "JP: $CLEAN_TEXT"
                        echo "EN: $TRANSLATION"
                        echo "---"
                    } >> "$HISTORY_FILE"
                fi
            fi
        fi
        
        # Wait before next capture
        sleep "$POLL_INTERVAL"
    done
}

# Manual test
test_region() {
    if [ ! -f "$REGION_FILE" ]; then
        echo "No region set. Run: $0 set-region"
        exit 1
    fi
    
    source "$REGION_FILE"
    echo "Testing region: $REGION"
    echo "Using MeikiOCR..."
    
    # Capture screenshot
    echo "Capturing..."
    maim -g "$REGION" -u "$TEMP_IMAGE" 2>/dev/null
    
    if [ ! -f "$TEMP_IMAGE" ]; then
        echo "Error: Failed to capture screenshot"
        exit 1
    fi
    
    echo "Image saved to $TEMP_IMAGE for debugging."
    
    # Run OCR
    echo "Running OCR..."
    TEXT=$(${PYTHON_CMD:-python3} "$MEIKIOCR_HELPER" "$TEMP_IMAGE" 2>&1)
    
    CLEAN_TEXT=$(clean_japanese_text "$TEXT")
    
    echo "Raw OCR: $TEXT"
    echo "Cleaned: $CLEAN_TEXT"
    
    if [ -n "$CLEAN_TEXT" ]; then
        TRANSLATION=$(translate_text "$CLEAN_TEXT")
        echo "Translation: $TRANSLATION"
    fi
}

# Main
case "${1:-monitor}" in
    "set-region"|"setup")
        check_deps
        set_region
        ;;
    "test")
        check_deps
        test_region
        ;;
    "monitor"|"start"|"")
        check_deps
        monitor_region
        ;;
    "help")
        echo "VN Real-Time Translator (Japanese -> English)"
        echo "Using MeikiOCR for improved accuracy"
        echo ""
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  set-region    Select the text box region"
        echo "  monitor       Start monitoring (default)"
        echo "  test          Test current region once (saves debug image)"
        echo "  help          Show this help"
        echo ""
        echo "Environment Variables:"
        echo "  VN_POLL_INTERVAL        Seconds between checks (default: 0.5)"
        echo "                          Increase to reduce CPU usage (e.g., 1.0 or 1.5)"
        echo "  VN_SIMILARITY_THRESHOLD Similarity threshold 0.0-1.0 (default: 0.85)"
        echo "                          Higher = more likely to skip similar lines"
        echo ""
        echo "Requirements:"
        echo "  - meikiocr_helper.py in the same directory"
        echo "  - pip install meikiocr opencv-python numpy"
        echo ""
        echo "CPU Usage Tips:"
        echo "  - Lower CPU: VN_POLL_INTERVAL=1.5 $0 monitor"
        echo "  - Use web interface with vn_translator_webserver.py"
        echo ""
        echo "Example workflow:"
        echo "  1. $0 set-region              # Select text box"
        echo "  2. $0 monitor                 # Start monitoring"
        echo "  3. python3 vn_translator_webserver.py  # Optional: Web UI for Yomitan"
        ;;
    *)
        check_deps
        monitor_region
        ;;
esac