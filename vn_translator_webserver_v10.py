#!/usr/bin/env python3
"""
Web Server for VN Translator
Serves OCR results on localhost for Yomitan integration
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import time
from pathlib import Path

# Configuration
PORT = 8765
CONFIG_DIR = Path.home() / ".vn_translator"
LAST_TEXT_FILE = CONFIG_DIR / "last_text.txt"
LAST_TRANSLATION_FILE = CONFIG_DIR / "last_translation.txt"

# HTML template with auto-refresh and Yomitan-friendly styling
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VN Translator - Live OCR</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        body {{
            font-family: 'Noto Sans JP', 'Hiragino Kaku Gothic Pro', 'Yu Gothic', sans-serif;
            background: #1a1a1a;
            color: #e0e0e0;
            padding: 20px;
            line-height: 1.8;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
        }}
        .header {{
            background: #2d2d2d;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        }}
        .header h1 {{
            color: #4a9eff;
            font-size: 24px;
            margin-bottom: 10px;
        }}
        .status {{
            display: flex;
            gap: 20px;
            font-size: 14px;
            color: #888;
        }}
        .status-item {{
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        .status-dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #4CAF50;
            animation: pulse 2s infinite;
        }}
        @keyframes pulse {{
            0%, 100% {{ opacity: 1; }}
            50% {{ opacity: 0.5; }}
        }}
        .text-box {{
            background: #2d2d2d;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            min-height: 200px;
        }}
        .japanese-text {{
            font-size: 28px;
            line-height: 2;
            letter-spacing: 0.05em;
            color: #ffffff;
            margin-bottom: 20px;
            word-break: break-all;
            user-select: text;
            cursor: text;
        }}
        .japanese-text:empty::before {{
            content: "Waiting for text...";
            color: #666;
            font-style: italic;
        }}
        .english-text {{
            font-size: 20px;
            line-height: 1.6;
            color: #b0b0b0;
            padding-top: 20px;
            border-top: 1px solid #444;
            word-break: break-word;
            user-select: text;
            cursor: text;
        }}
        .english-text:empty {{
            display: none;
        }}
        .meta-info {{
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #444;
            font-size: 14px;
            color: #888;
        }}
    </style>
    <script>
        let lastJapanese = '';
        let lastEnglish = '';
        
        async function updateText() {{
            try {{
                const response = await fetch('/api/text');
                const data = await response.json();
                
                // Update if either text has changed
                if (data.text !== lastJapanese || data.translation !== lastEnglish) {{
                    if (data.text !== lastJapanese) {{
                        document.getElementById('japanese-text').textContent = data.text;
                        document.getElementById('char-count').textContent = data.text.length;
                        lastJapanese = data.text;
                    }}
                    
                    if (data.translation !== lastEnglish) {{
                        document.getElementById('english-text').textContent = data.translation || '';
                        lastEnglish = data.translation;
                    }}
                    
                    document.getElementById('last-update').textContent = 
                        new Date(data.timestamp * 1000).toLocaleTimeString();
                }}
            }} catch (error) {{
                console.error('Failed to fetch text:', error);
            }}
        }}
        
        // Update every 500ms
        setInterval(updateText, 500);
        
        // Initial load
        updateText();
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="status">
                <div class="status-item">
                    <div class="status-dot"></div>
                    <span>Live</span>
                </div>
                <div class="status-item">
                    Last update: <span id="last-update">-</span>
                </div>
                <div class="status-item">
                    Characters: <span id="char-count">0</span>
                </div>
            </div>
        </div>
        
        <div class="text-box">
            <div class="japanese-text" id="japanese-text"></div>
            <div class="english-text" id="english-text"></div>
        </div>
    </div>
</body>
</html>
"""

class TranslatorHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default logging
        pass
    
    def do_GET(self):
        if self.path == '/':
            # Serve main page
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            html = HTML_TEMPLATE.format(port=PORT)
            self.wfile.write(html.encode('utf-8'))
            
        elif self.path == '/api/text':
            # Serve current text as JSON
            text = ""
            translation = ""
            timestamp = 0
            
            if LAST_TEXT_FILE.exists():
                try:
                    text = LAST_TEXT_FILE.read_text(encoding='utf-8').strip()
                    timestamp = LAST_TEXT_FILE.stat().st_mtime
                except Exception as e:
                    print(f"Error reading text file: {e}")
            
            if LAST_TRANSLATION_FILE.exists():
                try:
                    translation = LAST_TRANSLATION_FILE.read_text(encoding='utf-8').strip()
                except Exception as e:
                    print(f"Error reading translation file: {e}")
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            response = {
                'text': text,
                'translation': translation,
                'timestamp': timestamp
            }
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
        
        else:
            # 404
            self.send_response(404)
            self.end_headers()

def main():
    # Ensure config directory exists
    CONFIG_DIR.mkdir(exist_ok=True)
    
    print(f"Starting VN Translator Web Server...")
    print(f"")
    print(f"Server running at: http://localhost:{PORT}")
    print(f"Open in browser:   http://127.0.0.1:{PORT}")
    print(f"")
    print(f"The OCR script should be running separately")
    print(f"")
    print(f"Press Ctrl+C to stop the server")
    print(f"{'=' * 60}")
    
    try:
        server = HTTPServer(('localhost', PORT), TranslatorHandler)
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\n\nShutting down server...")
        server.shutdown()

if __name__ == "__main__":
    main()