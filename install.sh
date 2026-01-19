#!/usr/bin/env bash
set -euo pipefail

# ================== ASCII ==================
cat <<'EOF'
_____/\\\\\\\\\\\____/\\\________/\\\__/\\\\\\\\\\\__/\\\\\\\\\\\\\___        
 ___/\\\/////////\\\_\/\\\_____/\\\//__\/////\\\///__\/\\\/////////\\\_       
  __\//\\\______\///__\/\\\__/\\\//_________\/\\\_____\/\\\_______\/\\\_      
   ___\////\\\_________\/\\\\\\//\\\_________\/\\\_____\/\\\\\\\\\\\\\/__     
    ______\////\\\______\/\\\//_\//\\\________\/\\\_____\/\\\/////////____    
     _________\////\\\___\/\\\____\//\\\_______\/\\\_____\/\\\_____________   
      __/\\\______\//\\\__\/\\\_____\//\\\______\/\\\_____\/\\\_____________  
       _\///\\\\\\\\\\\/___\/\\\______\//\\\__/\\\\\\\\\\\_\/\\\_____________ 
        ___\///////////_____\///________\///__\///////////__\///______________
EOF

# ================== LOGS ==================
log() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*"; }
err() { echo -e "[ERR] $*" >&2; exit 1; }

# ================== READONLY ==================
log "Disabling SteamOS readonly..."
sudo steamos-readonly disable

# ================== CONSTANTS ==================
ZAPRET_DIR="/opt/zapret"
ZAPRET_REPO="https://github.com/Sergeydigl3/zapret-discord-youtube-linux"
NFQWS_PATH="$ZAPRET_DIR/nfqws"

CHAOTIC_KEY="3056513887B78AEB"
CHAOTIC_KEY_URL="https://cdn-mirror.chaotic.cx/chaotic-aur"
WARP_PACKAGE="cloudflare-warp-bin"

# ================== NFTABLES ==================
install_nftables() {
    command -v nft >/dev/null 2>&1 && return
    log "Installing nftables..."
    sudo pacman -S --noconfirm nftables
    sudo systemctl enable --now nftables.service || warn "Cannot enable nftables.service"
}

check_nftables() {
    sudo nft list tables >/dev/null 2>&1 || err "nftables installed but not working"
    log "nftables OK"
}

# ================== ZAPRET ==================
setup_zapret() {
    install_nftables
    check_nftables

    [[ -d "$ZAPRET_DIR" ]] || sudo git clone "$ZAPRET_REPO" "$ZAPRET_DIR"
    cd "$ZAPRET_DIR"
    chmod +x ./install.sh
    chmod +x ./nfqws

    STRATEGIES=(general*.bat discord.bat)
    SUCCESS=false

    for strat in "${STRATEGIES[@]}"; do
        log "Trying strategy: $strat"
        ./install.sh --strategy "$strat" --nointeractive
        sleep 3

        # Проверка nfqws
        if ! pgrep -f nfqws >/dev/null 2>&1; then
            warn "nfqws not running, trying next strategy"
            continue
        fi

        # Проверка ping + curl
        ping -c 2 youtube.com >/dev/null 2>&1 || { warn "Ping failed, trying next strategy"; continue; }
        curl -fsSL https://www.youtube.com >/dev/null 2>&1 || { warn "HTTP failed, trying next strategy"; continue; }

        SUCCESS=true
        log "Strategy $strat successful"
        break
    done

    $SUCCESS || err "No strategy worked for zapret"
}

# ================== WARP ==================
install_aur_warp() {
    log "Installing Chaotic-AUR keyring..."
    sudo pacman-key --init
    sudo pacman-key --populate
    sudo pacman-key --recv-key $CHAOTIC_KEY --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key $CHAOTIC_KEY

    sudo pacman -U --noconfirm \
        $CHAOTIC_KEY_URL/chaotic-keyring.pkg.tar.zst \
        $CHAOTIC_KEY_URL/chaotic-mirrorlist.pkg.tar.zst

    grep -q "\[chaotic-aur]" /etc/pacman.conf || \
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf

    sudo pacman -Syy

    log "Installing Cloudflare WARP..."
    sudo pacman -S --noconfirm $WARP_PACKAGE

    sudo systemctl enable --now warp-svc
}

connect_warp() {
    log "Registering and connecting WARP..."
    warp-cli registration new || true
    warp-cli mode warp+doh || true

    for i in {1..5}; do
        warp-cli connect || true
        sleep 5
        if warp-cli status | grep -qi "Connected"; then
            log "WARP successfully connected"
            return
        fi
        warn "WARP connection attempt $i failed, retrying..."
    done
    err "WARP failed to connect"
}

# ================== STEAMOS UPDATE ==================
update_steamos() {
    log "Running SteamOS update..."
    if ! command -v steamos-update >/dev/null 2>&1; then
        warn "steamos-update not found, skipping"
        return
    fi

    sudo steamos-update check || warn "No updates available"
    sudo steamos-update || warn "Update finished with warnings"
    log "SteamOS update completed"
}

# ================== MAIN ==================
main() {
    # 1. Устанавливаем zapret и находим рабочую стратегию
    setup_zapret

    # 2. Устанавливаем Chaotic-AUR + WARP
    install_aur_warp

    # 3. Подключаем WARP и проверяем соединение
    connect_warp

    # 4. Только после успешного WARP обновляем SteamOS
    update_steamos

    # 5. Включаем readonly
    log "Re-enabling SteamOS readonly..."
    sudo steamos-readonly enable

    # 6. Перезагрузка
    log "Rebooting Steam Deck..."
    sudo reboot
}

main
