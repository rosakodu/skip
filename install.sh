#!/usr/bin/env bash
set -euo pipefail
# set -x   # ← раскомментируй для полного debug-режима (очень много вывода)

LOG_FILE="/tmp/skip_install_$(date +%Y%m%d_%H%M%S).log"
echo "SKIP install log started at $(date)" > "$LOG_FILE"

log() {
    echo -e "${BLUE}[SKIP]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${WHITE}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

err() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Последние 15 строк лога:" | tee -a "$LOG_FILE"
    tail -n 15 "$LOG_FILE" >&2
    echo "Полный лог: $LOG_FILE" >&2
    exit 1
}

# ================== ASCII ==================
cat <<'EOF'
_____/\\\\\\\\\\\____/\\\________/\\\__/\\\\\\\\\\\__/\\\\\\\\\\\\\___        
___/\\\/////////\\\_\/\\\_____/\\\//__\/////\\\///__\/\\\/////////\\\_       
__\//\\\______\///__\/\\\__/\\\//_________\/\\\_____\/\\\_______\/\\\_      
___\////\\\_________\/\\\\\\//\\\_________\/\\\_____\/\\\\\\\\\\\\\/__     
______\////\\\______\/\\\//_\//\\\________\/\\\_____\/\\\/////////____    
_______\////\\\___\/\\\____\//\\\_______\/\\\_____\/\\\_____________   
______/\\\______\//\\\__\/\\\_____\//\\\______\/\\\_____\/\\\_____________  
_____\///\\\\\\\\\\\/___\/\\\______\//\\\__/\\\\\\\\\\\_\/\\\_____________ 
______\///////////_____\///________\///__\///////////__\///______________
EOF

# =============================================
#   SKIP installer — ZapretDeck + WARP
# =============================================

WHITE='\033[1;37m'
BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m'

# ─── Предварительный sudo ─────────────────────────────────────────────────────
log "Проверка sudo (введите пароль, если потребуется)..."
sudo -v 2>&1 | tee -a "$LOG_FILE" || err "Не удалось получить sudo-права"
sudo -v -n 2>&1 | tee -a "$LOG_FILE" || true   # продлеваем кэш

# ─── 1. Readonly disable ──────────────────────────────────────────────────────
if command -v steamos-readonly >/dev/null 2>&1; then
    log "Отключаем readonly..."
    sudo steamos-readonly disable 2>&1 | tee -a "$LOG_FILE" || err "readonly disable failed"
fi

# ─── 2. Скачивание ZapretDeck ─────────────────────────────────────────────────
WORKDIR="$HOME/Downloads/zapretdeck_install_$$"
log "Создаём временную папку: $WORKDIR"
mkdir -p "$WORKDIR" 2>&1 | tee -a "$LOG_FILE" || err "Не удалось создать $WORKDIR"
cd "$WORKDIR" || err "cd $WORKDIR failed"

LATEST_VERSION="v0.1.8"  # ← обновляй при новой версии
ARCHIVE="ZapretDeck_${LATEST_VERSION}.tar.gz"
URL="https://github.com/rosakodu/zapretdeck/releases/download/${LATEST_VERSION}/${ARCHIVE}"

log "Скачиваем $URL ..."
curl -L -o "$ARCHIVE" "$URL" 2>&1 | tee -a "$LOG_FILE" || err "curl download failed"

log "Проверяем архив..."
[[ -s "$ARCHIVE" ]] || err "Скачанный архив пустой или отсутствует"

log "Распаковываем..."
tar -xzf "$ARCHIVE" --strip-components=1 2>&1 | tee -a "$LOG_FILE" || err "tar распаковка failed"

rm -f "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"

log "Проверяем install.sh..."
[[ -f "install.sh" && -x "install.sh" ]] || err "install.sh не найден или не исполняемый"

# ─── 3. Установка ZapretDeck ──────────────────────────────────────────────────
log "Запускаем sudo ./install.sh ..."
sudo ./install.sh 2>&1 | tee -a "$LOG_FILE" || err "Установка ZapretDeck провалилась"

log "Проверяем наличие /opt/zapretdeck/main_script.sh ..."
[[ -x "/opt/zapretdeck/main_script.sh" ]] || err "main_script.sh не установлен или не исполняемый"

# ─── 4. Автоподбор стратегии ──────────────────────────────────────────────────
log "Запускаем автоподбор: sudo /opt/zapretdeck/main_script.sh auto"
sudo /opt/zapretdeck/main_script.sh auto 2>&1 | tee -a "$LOG_FILE" || err "Автоподбор (main_script.sh auto) провалился"

sleep 8   # даём время nfqws запуститься и правилам примениться

log "Проверяем YouTube..."
if curl -4fs --connect-timeout 12 https://www.youtube.com >/dev/null 2>&1; then
    log "YouTube доступен ✓ (обход работает)"
else
    warn "YouTube НЕ доступен после автоподбора"
    warn "Посмотрите лог: $LOG_FILE"
    warn "Возможно, автоподбор не нашёл подходящую стратегию — запустите ZapretDeck вручную"
    # exit 1   # ← если хочешь остановить скрипт здесь — раскомментируй
fi

# ─── 5. WARP ──────────────────────────────────────────────────────────────────
log "Настройка WARP..."

sudo pacman-key --init 2>&1 | tee -a "$LOG_FILE" || true
sudo pacman-key --populate 2>&1 | tee -a "$LOG_FILE" || true
sudo pacman-key --recv-key --keyserver keyserver.ubuntu.com 3056513887B78AEB 2>&1 | tee -a "$LOG_FILE"
sudo pacman-key --lsign-key 3056513887B78AEB 2>&1 | tee -a "$LOG_FILE"

sudo pacman -U --noconfirm \
    https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst \
    https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst 2>&1 | tee -a "$LOG_FILE" || true

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf 2>&1 | tee -a "$LOG_FILE"
fi

sudo pacman -Syy 2>&1 | tee -a "$LOG_FILE"
sudo pacman -S --noconfirm --needed cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || err "Установка warp-bin failed"

log "Запуск warp-svc..."
sudo systemctl enable --now warp-svc 2>&1 | tee -a "$LOG_FILE" || err "systemctl warp-svc failed"

warp-cli registration new 2>&1 | tee -a "$LOG_FILE" || true
warp-cli mode warp+doh 2>&1 | tee -a "$LOG_FILE" || true

CONNECTED=false
for i in {1..10}; do
    log "Попытка подключения WARP #$i..."
    warp-cli connect 2>&1 | tee -a "$LOG_FILE" || true
    sleep 6
    if warp-cli status 2>&1 | tee -a "$LOG_FILE" | grep -qi "Connected"; then
        log "WARP подключён ✓"
        CONNECTED=true
        break
    fi
done

[[ $CONNECTED != true ]] && warn "WARP не подключился автоматически — попробуйте warp-cli connect вручную"

# ─── 6. SteamOS update + readonly + reboot ────────────────────────────────
if command -v steamos-update >/dev/null 2>&1; then
    log "Обновление SteamOS..."
    sudo steamos-update check 2>&1 | tee -a "$LOG_FILE" || true
    sudo steamos-update 2>&1 | tee -a "$LOG_FILE" || warn "steamos-update завершился с ошибками"
fi

if command -v steamos-readonly >/dev/null 2>&1; then
    log "Включаем readonly обратно..."
    sudo steamos-readonly enable 2>&1 | tee -a "$LOG_FILE" || true
fi

log ""
log "──────────────────────────────────────────────"
log "SKIP завершён. Лог: $LOG_FILE"
log "Перезагрузка через 10 сек (Ctrl+C — отменить)"
log "──────────────────────────────────────────────"
sleep 10

sudo reboot
