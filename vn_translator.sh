#!/bin/bash

# VN Translator - Unified Launcher
# Manages both the OCR monitor and web server

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.vn_translator"
PID_FILE="$CONFIG_DIR/pids"

OCR_SCRIPT="$SCRIPT_DIR/vn_translator_meikiocr_v10.sh"
WEB_SCRIPT="$SCRIPT_DIR/vn_translator_webserver_v10.py"

mkdir -p "$CONFIG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

start_services() {
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        if check_running; then
            echo -e "${YELLOW}Services already running. Use 'stop' first or 'restart'.${NC}"
            exit 1
        else
            # Stale PID file
            rm -f "$PID_FILE"
        fi
    fi

    # Check if region is set
    if [ ! -f "$CONFIG_DIR/region.conf" ]; then
        echo -e "${YELLOW}No region set. Setting up now...${NC}"
        "$OCR_SCRIPT" set-region
        if [ $? -ne 0 ]; then
            echo -e "${RED}Region setup failed.${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}Starting VN Translator...${NC}"

    # Start web server in background
    python3 "$WEB_SCRIPT" > "$CONFIG_DIR/webserver.log" 2>&1 &
    WEB_PID=$!

    # Start OCR monitor in background
    "$OCR_SCRIPT" monitor > "$CONFIG_DIR/ocr.log" 2>&1 &
    OCR_PID=$!

    # Save PIDs
    echo "OCR_PID=$OCR_PID" > "$PID_FILE"
    echo "WEB_PID=$WEB_PID" >> "$PID_FILE"

    # Give processes a moment to start
    sleep 1

    # Verify they started
    if kill -0 "$OCR_PID" 2>/dev/null && kill -0 "$WEB_PID" 2>/dev/null; then
        echo -e "${GREEN}✓ OCR monitor started (PID: $OCR_PID)${NC}"
        echo -e "${GREEN}✓ Web server started (PID: $WEB_PID)${NC}"
        echo ""
        echo "Web UI: http://localhost:8765"
        echo "Logs:   $CONFIG_DIR/ocr.log"
        echo "        $CONFIG_DIR/webserver.log"
        echo ""
        echo "Use '$0 stop' to stop services"
        echo "Use '$0 logs' to tail the OCR log"
    else
        echo -e "${RED}Failed to start services. Check logs in $CONFIG_DIR/${NC}"
        stop_services
        exit 1
    fi
}

stop_services() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No services running (no PID file found)"
        return 0
    fi

    source "$PID_FILE"

    echo "Stopping services..."

    # Stop OCR monitor
    if [ -n "$OCR_PID" ] && kill -0 "$OCR_PID" 2>/dev/null; then
        kill "$OCR_PID" 2>/dev/null
        wait "$OCR_PID" 2>/dev/null
        echo -e "${GREEN}✓ OCR monitor stopped${NC}"
    fi

    # Stop web server
    if [ -n "$WEB_PID" ] && kill -0 "$WEB_PID" 2>/dev/null; then
        kill "$WEB_PID" 2>/dev/null
        wait "$WEB_PID" 2>/dev/null
        echo -e "${GREEN}✓ Web server stopped${NC}"
    fi

    rm -f "$PID_FILE"
    echo "All services stopped."
}

check_running() {
    if [ ! -f "$PID_FILE" ]; then
        return 1
    fi

    source "$PID_FILE"

    if kill -0 "$OCR_PID" 2>/dev/null || kill -0 "$WEB_PID" 2>/dev/null; then
        return 0
    fi

    return 1
}

show_status() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}Services not running${NC}"
        return
    fi

    source "$PID_FILE"

    echo "VN Translator Status:"
    echo ""

    if [ -n "$OCR_PID" ] && kill -0 "$OCR_PID" 2>/dev/null; then
        echo -e "  OCR Monitor: ${GREEN}running${NC} (PID: $OCR_PID)"
    else
        echo -e "  OCR Monitor: ${RED}stopped${NC}"
    fi

    if [ -n "$WEB_PID" ] && kill -0 "$WEB_PID" 2>/dev/null; then
        echo -e "  Web Server:  ${GREEN}running${NC} (PID: $WEB_PID)"
    else
        echo -e "  Web Server:  ${RED}stopped${NC}"
    fi

    echo ""

    # Show recent activity
    if [ -f "$CONFIG_DIR/last_text.txt" ]; then
        echo "Last captured text:"
        echo "  $(cat "$CONFIG_DIR/last_text.txt")"
    fi
}

show_logs() {
    if [ -f "$CONFIG_DIR/ocr.log" ]; then
        tail -f "$CONFIG_DIR/ocr.log"
    else
        echo "No log file found. Start services first."
    fi
}

clear_history() {
    if [ -f "$CONFIG_DIR/history.log" ]; then
        rm "$CONFIG_DIR/history.log"
        echo "History cleared."
    else
        echo "No history file found."
    fi
}

# Handle Ctrl+C during foreground mode
cleanup() {
    echo ""
    stop_services
    exit 0
}

run_foreground() {
    # Check if region is set
    if [ ! -f "$CONFIG_DIR/region.conf" ]; then
        echo -e "${YELLOW}No region set. Setting up now...${NC}"
        "$OCR_SCRIPT" set-region
        if [ $? -ne 0 ]; then
            echo -e "${RED}Region setup failed.${NC}"
            exit 1
        fi
    fi

    trap cleanup SIGINT SIGTERM

    echo -e "${GREEN}Starting VN Translator (foreground mode)...${NC}"
    echo "Press Ctrl+C to stop both services"
    echo ""

    # Start web server in background
    python3 "$WEB_SCRIPT" &
    WEB_PID=$!

    # Small delay to let web server print its startup message
    sleep 0.5
    echo ""

    # Run OCR monitor in foreground
    "$OCR_SCRIPT" monitor &
    OCR_PID=$!

    # Save PIDs for cleanup
    echo "OCR_PID=$OCR_PID" > "$PID_FILE"
    echo "WEB_PID=$WEB_PID" >> "$PID_FILE"

    # Wait for either to exit
    wait $OCR_PID $WEB_PID
    cleanup
}

case "${1:-}" in
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        stop_services
        sleep 1
        start_services
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "set-region"|"setup")
        "$OCR_SCRIPT" set-region
        ;;
    "clear-history")
        clear_history
        ;;
    "run"|"")
        run_foreground
        ;;
    "help"|"-h"|"--help")
        echo "VN Translator - Unified Launcher"
        echo ""
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  run           Run in foreground with live output (default)"
        echo "  start         Start services in background"
        echo "  stop          Stop background services"
        echo "  restart       Restart background services"
        echo "  status        Show service status"
        echo "  logs          Tail the OCR log (background mode)"
        echo "  set-region    Select screen region for capture"
        echo "  clear-history Clear translation history"
        echo "  help          Show this help"
        echo ""
        echo "Files:"
        echo "  ~/.vn_translator/history.log  Translation history"
        echo "  ~/.vn_translator/ocr.log      OCR monitor log (background mode)"
        echo "  ~/.vn_translator/webserver.log Web server log (background mode)"
        echo ""
        echo "Examples:"
        echo "  $0              # Run in foreground (Ctrl+C to stop)"
        echo "  $0 start        # Run in background"
        echo "  $0 status       # Check if running"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
