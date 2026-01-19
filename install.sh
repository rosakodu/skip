     ___/\/\/\/\/\__/\/\____/\/\__/\/\/\/\__/\/\/\/\/\___
    _/\/\__________/\/\__/\/\______/\/\____/\/\____/\/\_ 
    ___/\/\/\/\____/\/\/\/\________/\/\____/\/\/\/\/\___  
   _________/\/\__/\/\__/\/\______/\/\____/\/\_________   
  _/\/\/\/\/\____/\/\____/\/\__/\/\/\/\__/\/\_________    
 ____________________________________________________

#!/bin/bash
set -e

if ! command -v steamos-session-select >/dev/null 2>&1; then
    echo "[!] This script must be run on SteamOS"
    exit 1
fi

echo "[*] Setting Desktop Mode as default boot session..."
steamos-session-select plasma

echo
echo "[✓] Desktop Mode is now the default"
echo "[i] Reboot Steam Deck to apply changes"
