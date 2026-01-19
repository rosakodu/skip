#!/bin/bash
set -e

if ! command -v steamos-session-select >/dev/null 2>&1; then
    echo "[!] This script must be run on SteamOS"
    exit 1
fi

echo "[*] Setting Game Mode as default boot session..."
steamos-session-select gamescope

echo
echo "[✓] Game Mode is now the default"
echo "[i] Reboot Steam Deck to apply changes"
