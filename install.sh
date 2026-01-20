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

# =============================================
#   SKIP installer — ZapretDeck + WARP
#   (rosakodu/skip)
# =============================================

WHITE='\033[1;37m'
BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m'

log()    { echo -e "${BLUE}[SKIP]${NC} $*"; }
warn()   { echo -e "${WHITE}[WARN]${NC} $*"; }
err()    { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Предварительный запрос sudo-пароля (чтобы не просил много раз) ───────────
log "Проверка sudo (введите пароль один раз, если потребуется)..."
sudo -v || err "Не удалось получить права sudo"
# Продлеваем кэш sudo на 15 минут (чтобы не просил повторно)
sudo -v -n || true

# ─── 1. Отключение readonly (SteamOS) ───────────────────────────────────────
if command -v steamos-readonly >/dev/null 2>&1; then
    log "Отключаем readonly режим..."
    sudo steamos-readonly disable || err "Не удалось отключить readonly"
fi

# ─── 2. Скачивание и установка ZapretDeck ────────────────────────────────────
WORKDIR="$HOME/Downloads/zapretdeck_install_$$"
mkdir -p "$WORKDIR"
cd "$WORKDIR" || err "Не удалось перейти в $WORKDIR"

LATEST_VERSION="v0.1.8"   # Обновляй эту строку при выходе новой версии
ARCHIVE="ZapretDeck_${LATEST_VERSION}.tar.gz"
URL="https://github.com/rosakodu/zapretdeck/releases/download/${LATEST_VERSION}/$ARCHIVE"

log "Скачиваем ZapretDeck $LATEST_VERSION..."
curl -L -o "$ARCHIVE" "$URL" || err "Не удалось скачать $URL"

log "Распаковываем..."
tar -xzf "$ARCHIVE" --strip-components=1 || err "Ошибка распаковки"

rm -f "$ARCHIVE"

chmod +x install.sh || err "install.sh не найден или не стал исполняемым"

log "Запускаем установку ZapretDeck..."
sudo ./install.sh || err "Установка ZapretDeck провалилась"

# ─── 3. Запуск автоподбора стратегии ─────────────────────────────────────────
log "Запускаем автоподбор стратегии в ZapretDeck..."
sudo /opt/zapretdeck/main_script.sh auto || err "Автоподбор стратегии не удался"

sleep 6

# Проверка результата
log "Проверяем доступ к YouTube..."
if curl -4fs --connect-timeout 10 https://www.youtube.com >/dev/null 2>&1; then
    log "Обход работает — YouTube доступен ✓"
else
    warn "YouTube всё ещё недоступен после автоподбора"
    warn "Возможно, стоит запустить ZapretDeck вручную и выбрать другую стратегию"
    # Можно добавить exit 1, если хочешь жёсткую остановку
fi

# ─── 4. Установка и настройка WARP ───────────────────────────────────────────
log "Устанавливаем Cloudflare WARP (chaotic-aur)..."

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

log "Запускаем и подключаем WARP..."
sudo systemctl enable --now warp-svc || err "Не удалось запустить warp-svc"

warp-cli registration new || true
warp-cli mode warp+doh || true

CONNECTED=false
for i in {1..10}; do
    warp-cli connect || true
    sleep 5
    if warp-cli status 2>/dev/null | grep -qi "Connected"; then
        log "WARP успешно подключён ✓"
        CONNECTED=true
        break
    fi
    warn "Попытка $i / 10..."
done

if [[ $CONNECTED != true ]]; then
    warn "Не удалось подключить WARP автоматически"
    warn "Попробуйте вручную: warp-cli connect"
fi

# ─── 5. Обновление SteamOS (если доступно) ───────────────────────────────────
if command -v steamos-update >/dev/null 2>&1; then
    log "Проверяем и применяем обновления SteamOS..."
    sudo steamos-update check || true
    sudo steamos-update || warn "Обновление SteamOS завершилось с предупреждениями"
else
    log "steamos-update не найден — пропускаем обновление"
fi

# ─── 6. Возврат readonly и перезагрузка ──────────────────────────────────────
if command -v steamos-readonly >/dev/null 2>&1; then
    log "Возвращаем readonly режим..."
    sudo steamos-readonly enable || true
fi

log ""
log "──────────────────────────────────────────────"
log "         SKIP завершён!"
log "   ZapretDeck + автоподбор + WARP (если подключился)"
log "   Перезагрузка через 10 секунд (Ctrl+C — отменить)"
log "──────────────────────────────────────────────"
sleep 10

sudo reboot
