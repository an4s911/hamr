#!/usr/bin/env bash
# OCR indexing wrapper
# Dependencies: python-click tesseract

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/ocr-index.py" "$@"
