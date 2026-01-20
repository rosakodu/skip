#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/tmp/skip_install_$(date +%Y%m%d_%H%M%S).log"
echo "SKIP install started at $(date)" > "$LOG_FILE"

# ================== ASCII ==================
cat <<'EOF'
_____/\\\\\\\\\____/\\\\________/\\\__/\\\\\\\\\__/\\\\\\\\\\_  
___/\\/\\\\\\/\\\_\/\\\\_____/\\\//__\/////\\\///__\/\\/\\\\\\\//\_      
__\//\\\______\///__\/\\\__/\\\//_________\/\\\_____\/\\\_______/\\_     
___\////\\\_________\/\\\\\\\//\\\_________\/\\\_____\/\\\\\\\\\\\/__   
______\////\\\______\/\\\//_//\\\________\/\\\_____\/\\/\\\\\\\//____  
______\////\\\___\/\\\____\//\\\________\/\\\_____\/\\\_____________  
______/\\\______\//\\\__\/\\\_____\//\\\______\/\\\_____\/\\\_____________ 
_____\///\\\\\\\/___\/\\\______\//\\\__/\\\\\\\\\_\/\\\_____________ 
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

# Определяем ОС
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_NAME="${NAME:-unknown}"
else
    OS_ID="unknown"
    OS_NAME="unknown"
fi
log "Определена ОС: $OS_NAME ($OS_ID)"

# Для SteamOS специфичные команды
if [[ "$OS_ID" == "steamos" ]] || [[ "$OS_NAME" == *"Steam"* ]]; then
    log "Обнаружена SteamOS — отключаем readonly..."
    if command -v steamos-readonly >/dev/null 2>&1; then
        sudo steamos-readonly disable 2>&1 | tee -a "$LOG_FILE" || true
    fi
else
    log "SteamOS не обнаружена, пропускаем steamos-readonly"
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
# curl с -L для редиректов GitHub и таймаутом
curl --connect-timeout 30 --max-time 120 -L -o "$ARCHIVE" "$URL" 2>&1 | tee -a "$LOG_FILE" || err "curl failed — проверьте URL или соединение"

FILE_SIZE=$(stat -c %s "$ARCHIVE" 2>/dev/null || echo 0)
log "Размер архива: ${FILE_SIZE} байт"

if [[ $FILE_SIZE -lt 1000000 ]]; then
    warn "Архив слишком маленький — вероятно скачана страница ошибки"
    log "Содержимое скачанного файла (первые 500 байт):"
    head -c 500 "$ARCHIVE" | tee -a "$LOG_FILE"
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

log "Запускаем автоподбор стратегии..."
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

# Проверка: уже установлен?
if command -v warp-cli >/dev/null 2>&1; then
    log "warp-cli уже установлен"
    # Проверяем, установлен ли cloudflare-warp
    if ! systemctl list-units --type=service | grep -q warp-svc; then
        log "warp-svc не запущен — устанавливаем cloudflare-warp"
        INSTALL_WARP=true
    else
        INSTALL_WARP=false
    fi
else
    INSTALL_WARP=true
fi

if [[ "$INSTALL_WARP" == "true" ]]; then
    log "Установка cloudflare-warp..."

    # Arch Linux — пробуем несколько источников
    if [[ "$OS_ID" == "arch" ]]; then
        # Попробовать официальный репозиторий
        if sudo pacman -Ss ^cloudflare-warp$ 2>/dev/null | grep -q "community/"; then
            sudo pacman -S --noconfirm cloudflare-warp 2>&1 | tee -a "$LOG_FILE" || warn "Не удалось установить из official"
        fi

        # Если не установлен — пробуем AUR
        if ! command -v warp-cli >/dev/null 2>&1; then
            if command -v yay >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm base-devel 2>&1 | tee -a "$LOG_FILE" || true
                yay -S --noconfirm cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || err "Установка warp из AUR failed"
            elif command -v paru >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm base-devel 2>&1 | tee -a "$LOG_FILE" || true
                paru -S --noconfirm cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || err "Установка warp из AUR failed"
            else
                # Ручная установка из AUR
                log "Установка cloudflare-warp-bin из AUR вручную..."
                cd "$WORKDIR"
                git clone https://aur.archlinux.org/cloudflare-warp-bin.git 2>&1 | tee -a "$LOG_FILE" || err "git clone failed"
                cd cloudflare-warp-bin
                makepkg -si --noconfirm 2>&1 | tee -a "$LOG_FILE" || err "makepkg failed"
                cd "$INSTALL_DIR"
            fi
        fi
    else
        # Для других ОС — универсальный способ
        sudo pacman -S --noconfirm --needed cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || \
        sudo pacman -S --noconfirm --needed cloudflare-warp 2>&1 | tee -a "$LOG_FILE" || \
        err "Установка warp failed"
    fi
fi

# Запуск сервиса
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now warp-svc 2>&1 | tee -a "$LOG_FILE" || warn "Не удалось включить warp-svc"
    sleep 3
else
    warn "systemctl не найден — пропускаем запуск сервиса"
fi

# Регистрация и подключение
log "Регистрация WARP..."
warp-cli registration new 2>&1 | tee -a "$LOG_FILE" || true

log "Установка режима warp+doh..."
warp-cli mode warp+doh 2>&1 | tee -a "$LOG_FILE" || true

log "Подключение к WARP..."
CONNECTED=false
for i in {1..10}; do
    log "WARP connect attempt $i"
    warp-cli connect 2>&1 | tee -a "$LOG_FILE" || true
    sleep 5
    STATUS=$(warp-cli status 2>&1 | tee -a "$LOG_FILE")
    if echo "$STATUS" | grep -qi "Connected"; then
        log "WARP подключён ✓"
        CONNECTED=true
        break
    fi
done

if [[ "$CONNECTED" != "true" ]]; then
    warn "WARP не удалось подключить. Проверьте лог."
fi

# Проверка YouTube после WARP
log "Проверка YouTube после WARP..."
if curl -4fs --connect-timeout 12 https://www.youtube.com >/dev/null 2>&1; then
    log "YouTube доступен ✓"
else
    warn "YouTube НЕ доступен"
fi

# Обновление системы
if [[ "$OS_ID" == "steamos" ]] || [[ "$OS_NAME" == *"Steam"* ]]; then
    if command -v steamos-update >/dev/null 2>&1; then
        log "Обновление SteamOS..."
        sudo steamos-update check 2>&1 | tee -a "$LOG_FILE" || true
        sudo steamos-update 2>&1 | tee -a "$LOG_FILE" || warn "Обновление SteamOS с ошибками"
    fi
elif [[ "$OS_ID" == "arch" ]]; then
    log "Обновление Arch Linux..."
    sudo pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE" || warn "Обновление Arch с ошибками"
fi

# Включаем readonly обратно для SteamOS
if [[ "$OS_ID" == "steamos" ]] || [[ "$OS_NAME" == *"Steam"* ]]; then
    if command -v steamos-readonly >/dev/null 2>&1; then
        sudo steamos-readonly enable 2>&1 | tee -a "$LOG_FILE" || true
    fi
fi

log ""
log "──────────────────────────────────────────────"
log "SKIP завершён. Лог: $LOG_FILE"
log "Перезагрузка через 10 сек (Ctrl+C — отменить)"
log "──────────────────────────────────────────────"
sleep 10

sudo reboot
