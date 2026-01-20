#!/usr/bin/env bash
set -euo pipefail

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

log()    { echo -e "${BLUE}[SKIP]${NC} $*"; }
warn()   { echo -e "${WHITE}[WARN]${NC} $*"; }
err()    { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

log "Проверка sudo..."
sudo -v || err "Не удалось получить права sudo"
sudo -v -n || true

# Отключаем readonly если SteamOS
if command -v steamos-readonly >/dev/null 2>&1; then
    log "Отключаем readonly..."
    sudo steamos-readonly disable || true
fi

# ─── Установка в домашний каталог ~/zapretdeck ───────────────────────────────
INSTALL_DIR="$HOME/zapretdeck"
log "Устанавливаем в домашний каталог: $INSTALL_DIR"

mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/zapret-latest" "$INSTALL_DIR/custom-strategies"

WORKDIR="$HOME/Downloads/zapretdeck_tmp_$$"
mkdir -p "$WORKDIR"
cd "$WORKDIR" || err "Не удалось перейти во временную папку"

VERSION="v.0.1.8"
ARCHIVE="ZapretDeck_v0.1.8.tar.gz"
URL="https://github.com/rosakodu/zapretdeck/releases/download/${VERSION}/${ARCHIVE}"

log "Скачиваем архив..."
curl -f -L -o "$ARCHIVE" "$URL" || err "Не удалось скачать архив"

FILE_SIZE=$(stat -c %s "$ARCHIVE" 2>/dev/null || echo 0)
(( FILE_SIZE < 1000000 )) && err "Архив слишком маленький (${FILE_SIZE} байт) — ошибка загрузки?"

log "Распаковываем в домашний каталог..."
tar -xzf "$ARCHIVE" -C "$INSTALL_DIR" --strip-components=1 || err "Ошибка распаковки"

# Удаляем временный архив
rm -f "$ARCHIVE"
cd "$INSTALL_DIR" || err "Не удалось перейти в $INSTALL_DIR"

# Делаем исполняемыми нужные файлы
chmod +x nfqws main_script.sh stop_and_clean_nft.sh rename_bat.sh 2>/dev/null || true

# Создаём/обновляем conf.env
cat > conf.env << 'EOF'
interface=any
auto_update=false
strategy=
gamefilter=false
EOF
chmod 666 conf.env

log "Установка завершена. Всё в $INSTALL_DIR"

# ─── Автоподбор стратегии ────────────────────────────────────────────────────
log "Запускаем автоподбор стратегии..."
./main_script.sh auto || err "Автоподбор стратегии завершился с ошибкой"

sleep 8

log "Проверяем доступ к YouTube..."
if curl -4fs --connect-timeout 12 https://www.youtube.com >/dev/null 2>&1; then
    log "YouTube доступен ✓ — обход работает"
else
    warn "YouTube НЕ доступен после автоподбора"
    warn "Смотрите лог: $INSTALL_DIR/debug.log"
    warn "Возможно, ни одна стратегия не подошла — попробуйте запустить ZapretDeck вручную"
fi

# ─── WARP ────────────────────────────────────────────────────────────────────
log "Устанавливаем и подключаем Cloudflare WARP..."

sudo pacman-key --init || true
sudo pacman-key --populate || true
sudo pacman-key --recv-key --keyserver keyserver.ubuntu.com 3056513887B78AEB
sudo pacman-key --lsign-key 3056513887B78AEB

sudo pacman -U --noconfirm \
    https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst \
    https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst || true

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
fi

sudo pacman -Syy
sudo pacman -S --noconfirm --needed cloudflare-warp-bin || err "Не удалось установить cloudflare-warp-bin"

sudo systemctl enable --now warp-svc || err "Не удалось запустить warp-svc"

warp-cli registration new || true
warp-cli mode warp+doh || true

CONNECTED=false
for i in {1..10}; do
    log "Попытка подключения WARP #$i"
    warp-cli connect || true
    sleep 5
    if warp-cli status 2>/dev/null | grep -qi "Connected"; then
        log "WARP успешно подключён ✓"
        CONNECTED=true
        break
    fi
done

if [[ $CONNECTED != true ]]; then
    warn "WARP не подключился автоматически"
    warn "Запустите вручную: warp-cli connect"
fi

# ─── Завершение ──────────────────────────────────────────────────────────────
if command -v steamos-update >/dev/null 2>&1; then
    log "Проверяем и применяем обновления SteamOS..."
    sudo steamos-update check || true
    sudo steamos-update || warn "Обновление SteamOS завершилось с предупреждениями"
fi

if command -v steamos-readonly >/dev/null 2>&1; then
    log "Возвращаем readonly режим..."
    sudo steamos-readonly enable || true
fi

log ""
log "──────────────────────────────────────────────"
log "         SKIP завершён!"
log "   Всё установлено в $HOME/zapretdeck"
log "   Перезагрузка через 10 секунд (Ctrl+C — отменить)"
log "──────────────────────────────────────────────"
sleep 10

sudo reboot
