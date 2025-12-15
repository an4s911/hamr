#!/usr/bin/env bash
# Thumbnail generator wrapper
# Dependencies: python-click python-loguru python-tqdm python-gobject gnome-desktop-4

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIO_USE_VFS=local python3 "$SCRIPT_DIR/thumbgen.py" "$@"
