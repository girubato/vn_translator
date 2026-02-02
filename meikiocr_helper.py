#!/usr/bin/env python3
"""
MeikiOCR Helper Script
Reads an image file and performs Japanese OCR using MeikiOCR
"""

import sys
import cv2
import numpy as np
from meikiocr import MeikiOCR

def main():
    if len(sys.argv) < 2:
        print("Usage: meikiocr_helper.py <image_file>", file=sys.stderr)
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    try:
        # Read the image
        image = cv2.imread(image_path)
        
        if image is None:
            print(f"Error: Could not read image from {image_path}", file=sys.stderr)
            sys.exit(1)
        
        # Initialize OCR (will be cached after first run)
        ocr = MeikiOCR()
        
        # Run OCR
        results = ocr.run_ocr(image)
        
        # Extract and print text
        text_lines = [line['text'] for line in results if line.get('text')]
        
        # Join all lines into a single string
        full_text = ''.join(text_lines)
        
        print(full_text)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()