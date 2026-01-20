#!/usr/bin/env bash
set -euo pipefail
# set -x   # ← раскомментируй для полного отладочного режима (очень много вывода)

LOG_FILE="/tmp/skip_install_$(date +%Y%m%d_%H%M%S).log"
echo "SKIP install started at $(date)" > "$LOG_FILE"

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

WHITE='\033[1;37m'
BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m'

log()    { echo -e "${BLUE}[SKIP]${NC} $*" | tee -a "$LOG_FILE"; }
warn()   { echo -e "${WHITE}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
err()    {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Последние 20 строк лога:" | tee -a "$LOG_FILE"
    tail -n 20 "$LOG_FILE" >&2
    echo "Полный лог: $LOG_FILE" >&2
    exit 1
}

log "Проверка sudo..."
sudo -v 2>&1 | tee -a "$LOG_FILE" || err "sudo failed"
sudo -v -n 2>&1 | tee -a "$LOG_FILE" || true

# Readonly disable
if command -v steamos-readonly >/dev/null 2>&1; then
    log "Отключаем readonly..."
    sudo steamos-readonly disable 2>&1 | tee -a "$LOG_FILE" || true
fi

INSTALL_DIR="$HOME/zapretdeck"
log "Установка в домашний каталог: $INSTALL_DIR"

mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/zapret-latest" "$INSTALL_DIR/custom-strategies" 2>&1 | tee -a "$LOG_FILE"

WORKDIR="$HOME/Downloads/zapretdeck_tmp_$$"
mkdir -p "$WORKDIR" 2>&1 | tee -a "$LOG_FILE"
cd "$WORKDIR" || err "cd $WORKDIR failed"

VERSION="v.0.1.8"
ARCHIVE="ZapretDeck_v0.1.8.tar.gz"
URL="https://github.com/rosakodu/zapretdeck/releases/download/${VERSION}/${ARCHIVE}"

log "Скачиваем: $URL"
curl -f --fail-with-body -L -o "$ARCHIVE" "$URL" 2>&1 | tee -a "$LOG_FILE" || err "curl failed — вероятно 404. Проверьте URL"

FILE_SIZE=$(stat -c %s "$ARCHIVE" 2>/dev/null || echo 0)
log "Размер архива: ${FILE_SIZE} байт"

if [[ $FILE_SIZE -lt 1000000 ]]; then
    warn "Архив слишком маленький — вероятно скачана страница ошибки"
    log "Содержимое скачанного файла (первые 300 байт):"
    head -c 300 "$ARCHIVE" | tee -a "$LOG_FILE"
    err "Скачан не .tar.gz (HTML-ошибка GitHub?)"
fi

log "Распаковываем в $INSTALL_DIR..."
tar -xzf "$ARCHIVE" -C "$INSTALL_DIR" --strip-components=1 2>&1 | tee -a "$LOG_FILE" || err "tar failed — файл не gzip или повреждён"

rm -f "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"

cd "$INSTALL_DIR" || err "cd $INSTALL_DIR failed"

log "Делаем файлы исполняемыми..."
chmod +x nfqws main_script.sh stop_and_clean_nft.sh rename_bat.sh 2>&1 | tee -a "$LOG_FILE" || true

log "Создаём/обновляем conf.env..."
cat > conf.env << 'EOF'
interface=any
auto_update=false
strategy=
gamefilter=false
EOF
chmod 666 conf.env 2>&1 | tee -a "$LOG_FILE"

log "Запускаем автоподбор..."
./main_script.sh auto 2>&1 | tee -a "$LOG_FILE" || err "main_script.sh auto failed"

sleep 8

log "Проверка YouTube..."
if curl -4fs --connect-timeout 12 https://www.youtube.com >/dev/null 2>&1; then
    log "YouTube доступен ✓"
else
    warn "YouTube НЕ доступен"
    warn "Смотрите: $INSTALL_DIR/debug.log"
fi

# WARP
log "Установка WARP..."
sudo pacman-key --init 2>&1 | tee -a "$LOG_FILE" || true
sudo pacman-key --populate 2>&1 | tee -a "$LOG_FILE" || true
sudo pacman-key --recv-key --keyserver keyserver.ubuntu.com 3056513887B78AEB 2>&1 | tee -a "$LOG_FILE"
sudo pacman-key --lsign-key 3056513887B78AEB 2>&1 | tee -a "$LOG_FILE"

sudo pacman -U --noconfirm \
    https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst \
    https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst 2>&1 | tee -a "$LOG_FILE" || true

grep -q "\[chaotic-aur\]" /etc/pacman.conf || {
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf 2>&1 | tee -a "$LOG_FILE"
}

sudo pacman -Syy 2>&1 | tee -a "$LOG_FILE"
sudo pacman -S --noconfirm --needed cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || err "Установка warp failed"

sudo systemctl enable --now warp-svc 2>&1 | tee -a "$LOG_FILE" || err "warp-svc failed"

warp-cli registration new 2>&1 | tee -a "$LOG_FILE" || true
warp-cli mode warp+doh 2>&1 | tee -a "$LOG_FILE" || true

for i in {1..10}; do
    log "WARP connect attempt $i"
    warp-cli connect 2>&1 | tee -a "$LOG_FILE" || true
    sleep 5
    if warp-cli status 2>&1 | tee -a "$LOG_FILE" | grep -qi Connected; then
        log "WARP подключён ✓"
        break
    fi
done

# Завершение
if command -v steamos-update >/dev/null 2>&1; then
    sudo steamos-update check 2>&1 | tee -a "$LOG_FILE" || true
    sudo steamos-update 2>&1 | tee -a "$LOG_FILE" || warn "Обновление SteamOS с ошибками"
fi

if command -v steamos-readonly >/dev/null 2>&1; then
    sudo steamos-readonly enable 2>&1 | tee -a "$LOG_FILE" || true
fi

log ""
log "──────────────────────────────────────────────"
log "SKIP завершён. Лог: $LOG_FILE"
log "Перезагрузка через 10 сек (Ctrl+C — отменить)"
log "──────────────────────────────────────────────"
sleep 10

sudo reboot
