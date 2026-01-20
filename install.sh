#!/usr/bin/env bash
set -euo pipefail

# ================== ЛОГИРОВАНИЕ ==================
LOG_DIR="/tmp/skip_install"
LOG_FILE="${LOG_DIR}/skip_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Уровни логирования
LOG_DEBUG(){ echo -e "${GRAY}[$(date '+%H:%M:%S')] [DEBUG]${NC} $*" | tee -a "$LOG_FILE"; }
LOG_INFO(){ echo -e "${BLUE}[$(date '+%H:%M:%S')] [INFO]${NC}  ${CYAN}●${NC} $*" | tee -a "$LOG_FILE"; }
LOG_OK(){ echo -e "${GREEN}[$(date '+%H:%M:%S')] [OK]    ${GREEN}✓${NC} $*" | tee -a "$LOG_FILE"; }
LOG_WARN(){ echo -e "${YELLOW}[$(date '+%H:%M:%S')] [WARN]  ${YELLOW}⚠${NC} $*" | tee -a "$LOG_FILE"; }
LOG_ERROR(){ echo -e "${RED}[$(date '+%H:%M:%S')] [ERROR] ${RED}✗${NC} $*" | tee -a "$LOG_FILE"; echo "" | tee -a "$LOG_FILE"; tail -n 20 "$LOG_FILE" >&2; echo "Full log: $LOG_FILE" >&2; exit 1; }

# Логгер с прогресс-баром
LOG_PROGRESS(){
    local current=$1
    local total=$2
    local msg=$3
    local percent=$((current * 100 / total))
    local bar=$(printf "█%.0s" $(seq 1 $((percent / 2))) 2>/dev/null || echo "")
    local empty=$(printf "░%.0s" $(seq 1 $((50 - percent / 2))) 2>/dev/null || echo "")
    echo -ne "\r${GRAY}[$(date '+%H:%M:%S')]${NC} [${GREEN}${bar}${GRAY}${empty}${NC}] ${percent}% ${msg}   " | tee -a "$LOG_FILE"
    [[ $current -eq $total ]] && echo "" | tee -a "$LOG_FILE"
}

# Логгер для curl/wget
LOG_DOWNLOAD(){
    local url=$1
    local dest=$2
    LOG_INFO "Downloading: $(basename "$dest")"
    curl -L --connect-timeout 30 --max-time 120 -o "$dest" "$url" 2>&1 | while read line; do
        echo -e "${GRAY}  └─ $line${NC}" >> "$LOG_FILE"
    done
}

echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║${NC}  SKIP Installer v1.0                                    ${WHITE}║${NC}"
echo -e "${WHITE}║${NC}  Log: ${CYAN}$LOG_FILE${NC}                              ${WHITE}║${NC}"
echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
echo "" | tee -a "$LOG_FILE"


# ================== ASCII ==================
cat <<'EOF'
     ___/\/\/\/\/\__/\/\____/\/\__/\/\/\/\__/\/\/\/\/\____/\/\____/\/\__/\/\/\/\/\____/\/\/\/\/\________/\/\______/\/\/\/\/\/\__/\/\/\/\/\/\__/\/\____/\/\_
    _/\/\__________/\/\__/\/\______/\/\____/\/\____/\/\__/\/\____/\/\__/\/\____/\/\__/\/\____/\/\____/\/\/\/\________/\/\__________/\/\______/\/\____/\/\_ 
   ___/\/\/\/\____/\/\/\/\________/\/\____/\/\/\/\/\____/\/\____/\/\__/\/\/\/\/\____/\/\____/\/\__/\/\____/\/\______/\/\__________/\/\________/\/\/\/\___  
  _________/\/\__/\/\__/\/\______/\/\____/\/\__________/\/\____/\/\__/\/\__________/\/\____/\/\__/\/\/\/\/\/\______/\/\__________/\/\__________/\/\_____   
 _/\/\/\/\/\____/\/\____/\/\__/\/\/\/\__/\/\____________/\/\/\/\____/\/\__________/\/\/\/\/\____/\/\____/\/\______/\/\__________/\/\__________/\/\_____    
______________________________________________________________________________________________________________________________________________________     
EOF

WHITE='\033[1;37m'
BLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m'

# Старые функции для совместимости (удалены - используются LOG_*)

LOG_INFO "Проверка sudo..."
sudo -v 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "sudo failed"
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
LOG_INFO "Определена ОС: $OS_NAME ($OS_ID)"

# Для SteamOS специфичные команды
if [[ "$OS_ID" == "steamos" ]] || [[ "$OS_NAME" == *"Steam"* ]]; then
    LOG_INFO "Обнаружена SteamOS — отключаем readonly..."
    if command -v steamos-readonly >/dev/null 2>&1; then
        sudo steamos-readonly disable 2>&1 | tee -a "$LOG_FILE" || true
    fi
else
    LOG_INFO "SteamOS не обнаружена, пропускаем steamos-readonly"
fi

INSTALL_DIR="$HOME/zapretdeck"
LOG_INFO "Установка в домашний каталог: $INSTALL_DIR"

mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/zapret-latest" "$INSTALL_DIR/custom-strategies" 2>&1 | tee -a "$LOG_FILE"

WORKDIR="$HOME/Downloads/zapretdeck_tmp_$"
mkdir -p "$WORKDIR" 2>&1 | tee -a "$LOG_FILE"
cd "$WORKDIR" || LOG_ERROR "cd $WORKDIR failed"

VERSION="v.0.1.8"
ARCHIVE="ZapretDeck_v0.1.8.tar.gz"
URL="https://github.com/rosakodu/zapretdeck/releases/download/${VERSION}/${ARCHIVE}"

LOG_INFO "Скачиваем: $URL"
# curl с -L для редиректов GitHub и таймаутом
curl --connect-timeout 30 --max-time 120 -L -o "$ARCHIVE" "$URL" 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "curl failed — проверьте URL или соединение"

FILE_SIZE=$(stat -c %s "$ARCHIVE" 2>/dev/null || echo 0)
LOG_INFO "Размер архива: ${FILE_SIZE} байт"

if [[ $FILE_SIZE -lt 1000000 ]]; then
    LOG_WARN "Архив слишком маленький — вероятно скачана страница ошибки"
    LOG_DEBUG "Содержимое скачанного файла (первые 500 байт):"
    head -c 500 "$ARCHIVE" | tee -a "$LOG_FILE"
    LOG_ERROR "Скачан не .tar.gz (HTML-ошибка GitHub?)"
fi

LOG_INFO "Распаковываем в $INSTALL_DIR..."

# Создаем временную директорию для распаковки
TEMP_UNPACK_DIR="$WORKDIR/temp_unpack"
mkdir -p "$TEMP_UNPACK_DIR"

# Распаковываем архив во временную директорию
tar -xzf "$ARCHIVE" -C "$TEMP_UNPACK_DIR" 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "tar failed"

# Проверяем структуру распакованных файлов
UNPACKED_ITEMS=("$TEMP_UNPACK_DIR"/*)
FIRST_ITEM="${UNPACKED_ITEMS[0]}"

# Если первый элемент - директория (а не файл), значит архив содержит вложенную папку
if [[ -d "$FIRST_ITEM" ]]; then
    LOG_DEBUG "Обнаружена вложенная папка: $(basename "$FIRST_ITEM") — используем --strip-components=1"
    tar -xzf "$ARCHIVE" -C "$INSTALL_DIR" --strip-components=1 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "tar failed with --strip-components=1"
else
    LOG_DEBUG "Файлы находятся в корне архива"
    tar -xzf "$ARCHIVE" -C "$INSTALL_DIR" 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "tar failed"
fi

# Удаляем временную директорию
rm -rf "$TEMP_UNPACK_DIR"

rm -f "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"
LOG_OK "Распаковка завершена"

cd "$INSTALL_DIR" || LOG_ERROR "cd $INSTALL_DIR failed"

LOG_INFO "Делаем файлы исполняемыми..."
chmod +x nfqws main_script.sh stop_and_clean_nft.sh rename_bat.sh 2>&1 | tee -a "$LOG_FILE" || true

LOG_INFO "Создаём/обновляем conf.env..."
cat > conf.env << 'EOF'
interface=any
auto_update=false
strategy=
gamefilter=false
EOF
chmod 666 conf.env 2>&1 | tee -a "$LOG_FILE"

LOG_INFO "Запускаем автоподбор стратегии..."
./main_script.sh auto 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "main_script.sh auto failed"

sleep 8

LOG_INFO "Проверка YouTube..."
# Диагностика перед проверкой YouTube
LOG_DEBUG "Проверка текущего DNS-сервера..."
if command -v nmcli >/dev/null 2>&1; then
    current_dns=$(nmcli dev show | grep "IP4.DNS" | head -n1 | cut -d' ' -f4- 2>/dev/null || echo "N/A")
    LOG_DEBUG "Текущий DNS: $current_dns"
else
    LOG_DEBUG "nmcli недоступен, проверяем resolv.conf"
    current_dns=$(grep "nameserver" /etc/resolv.conf | head -n1 | cut -d' ' -f2 2>/dev/null || echo "N/A")
    LOG_DEBUG "DNS из /etc/resolv.conf: $current_dns"
fi

LOG_DEBUG "Проверка маршрутов..."
route_info=$(ip route | grep -E "(warp|default)" 2>/dev/null || echo "No routes found")
LOG_DEBUG "Маршруты: $route_info"

# Проверка YouTube
youtube_result=$(curl -4fs --connect-timeout 12 https://www.youtube.com 2>&1)
if [[ $? -eq 0 ]]; then
    LOG_OK "YouTube доступен"
else
    LOG_WARN "YouTube НЕ доступен"
    LOG_DEBUG "Ошибка при проверке YouTube: $youtube_result"
    
    # Проверим доступность других ресурсов
    LOG_DEBUG "Проверка доступности других ресурсов:"
    
    google_result=$(curl -4fs --connect-timeout 12 https://www.google.com 2>&1)
    if [[ $? -eq 0 ]]; then
        LOG_DEBUG "  - Google: доступен"
    else
        LOG_DEBUG "  - Google: НЕ доступен - $google_result"
    fi
    
    github_result=$(curl -4fs --connect-timeout 12 https://www.github.com 2>&1)
    if [[ $? -eq 0 ]]; then
        LOG_DEBUG "  - GitHub: доступен"
    else
        LOG_DEBUG "  - GitHub: НЕ доступен - $github_result"
    fi
    
    # Проверим DNS-резолвинг
    LOG_DEBUG "Проверка DNS-резолвинга для youtube.com..."
    dns_resolve=$(nslookup youtube.com 2>/dev/null || echo "DNS resolve failed")
    LOG_DEBUG "  - Результат: $dns_resolve"
    
    if [[ -f "$INSTALL_DIR/debug.log" ]]; then
        LOG_WARN "Смотрите: $INSTALL_DIR/debug.log"
        LOG_DEBUG "Последние 20 строк debug.log:"
        tail -n 20 "$INSTALL_DIR/debug.log" 2>&1 | while read line; do
            echo -e "${GRAY}  └─ $line${NC}" | tee -a "$LOG_FILE"
        done
    else
        LOG_WARN "Файл $INSTALL_DIR/debug.log не найден или недоступен"
    fi
fi

# WARP
LOG_INFO "Установка WARP..."

# Проверка: уже установлен?
if command -v warp-cli >/dev/null 2>&1; then
    LOG_INFO "warp-cli уже установлен"
    # Проверяем, установлен ли cloudflare-warp
    if ! systemctl list-units --type=service | grep -q warp-svc; then
        LOG_WARN "warp-svc не запущен — устанавливаем cloudflare-warp"
        # Проверим, есть ли пакет в системе
        if command -v pacman >/dev/null 2>&1; then
            if pacman -Qs cloudflare-warp >/dev/null 2>&1; then
                LOG_DEBUG "Пакет cloudflare-warp обнаружен в системе"
                # Попробуем включить и запустить сервис
                sudo systemctl enable --now warp-svc 2>&1 | tee -a "$LOG_FILE" || LOG_WARN "Не удалось включить warp-svc"
                sleep 3
                # Проверим статус сервиса
                svc_status=$(systemctl is-active warp-svc 2>&1)
                LOG_DEBUG "Статус warp-svc: $svc_status"
                if [[ "$svc_status" == "active" ]]; then
                    INSTALL_WARP=false
                    LOG_INFO "warp-svc запущен успешно"
                else
                    INSTALL_WARP=true
                fi
            else
                INSTALL_WARP=true
            fi
        else
            # Для других систем просто устанавливаем
            INSTALL_WARP=true
        fi
    else
        INSTALL_WARP=false
    fi
else
    INSTALL_WARP=true
fi

if [[ "$INSTALL_WARP" == "true" ]]; then
    LOG_INFO "Установка cloudflare-warp..."

    # Arch Linux — пробуем несколько источников
    if [[ "$OS_ID" == "arch" ]]; then
        # Попробовать официальный репозиторий
        if sudo pacman -Ss ^cloudflare-warp$ 2>/dev/null | grep -q "community/"; then
            sudo pacman -S --noconfirm cloudflare-warp 2>&1 | tee -a "$LOG_FILE" || LOG_WARN "Не удалось установить из official"
        fi

        # Если не установлен — пробуем AUR
        if ! command -v warp-cli >/dev/null 2>&1; then
            if command -v yay >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm base-devel 2>&1 | tee -a "$LOG_FILE" || true
                yay -S --noconfirm cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "Установка warp из AUR failed"
            elif command -v paru >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm base-devel 2>&1 | tee -a "$LOG_FILE" || true
                paru -S --noconfirm cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "Установка warp из AUR failed"
            else
                # Ручная установка из AUR
                LOG_INFO "Установка cloudflare-warp-bin из AUR вручную..."
                cd "$WORKDIR"
                git clone https://aur.archlinux.org/cloudflare-warp-bin.git 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "git clone failed"
                cd cloudflare-warp-bin
                makepkg -si --noconfirm 2>&1 | tee -a "$LOG_FILE" || LOG_ERROR "makepkg failed"
                cd "$INSTALL_DIR"
            fi
        fi
    else
        # Для других ОС — универсальный способ
        sudo pacman -S --noconfirm --needed cloudflare-warp-bin 2>&1 | tee -a "$LOG_FILE" || \
        sudo pacman -S --noconfirm --needed cloudflare-warp 2>&1 | tee -a "$LOG_FILE" || \
        LOG_ERROR "Установка warp failed"
    fi
fi

# Запуск сервиса
if command -v systemctl >/dev/null 2>&1; then
    # Проверим статус сервиса перед запуском
    svc_status=$(systemctl is-active warp-svc 2>/dev/null || echo "inactive")
    if [[ "$svc_status" != "active" ]]; then
        LOG_INFO "Запуск warp-svc сервиса..."
        sudo systemctl enable --now warp-svc 2>&1 | tee -a "$LOG_FILE" || LOG_WARN "Не удалось включить warp-svc"
        sleep 5
        
        # Проверим статус снова после запуска
        svc_status_after=$(systemctl is-active warp-svc 2>/dev/null || echo "inactive")
        LOG_DEBUG "Статус warp-svc после запуска: $svc_status_after"
        
        if [[ "$svc_status_after" != "active" ]]; then
            LOG_WARN "Сервис warp-svc не запущен. Попытка перезапуска..."
            sudo systemctl restart warp-svc 2>&1 | tee -a "$LOG_FILE" || LOG_WARN "Не удалось перезапустить warp-svc"
            sleep 5
        fi
    else
        LOG_DEBUG "Сервис warp-svc уже активен"
    fi
    sleep 3
else
    LOG_WARN "systemctl не найден — пропускаем запуск сервиса"
fi

# Регистрация и подключение
LOG_INFO "Регистрация WARP..."
registration_result=$(warp-cli registration new 2>&1 | tee -a "$LOG_FILE")
if [[ $? -eq 0 ]]; then
    LOG_DEBUG "Регистрация WARP успешна"
else
    LOG_WARN "Ошибка регистрации WARP: $registration_result"
fi

LOG_INFO "Установка режима warp+doh..."
warp-cli mode warp+doh 2>&1 | tee -a "$LOG_FILE" || true

LOG_INFO "Подключение к WARP..."
CONNECTED=false
for i in {1..10}; do
    LOG_INFO "WARP connect attempt $i"
    warp_connect_result=$(warp-cli connect 2>&1 | tee -a "$LOG_FILE")
    if [[ $? -eq 0 ]]; then
        LOG_DEBUG "Команда warp-cli connect выполнена (попытка $i)"
    else
        LOG_DEBUG "Ошибка команды warp-cli connect (попытка $i): $warp_connect_result"
    fi
    sleep 5
    STATUS=$(warp-cli status 2>&1 | tee -a "$LOG_FILE")
    if echo "$STATUS" | grep -qi "Connected"; then
        LOG_OK "WARP подключён"
        CONNECTED=true
        break
    else
        LOG_DEBUG "Статус WARP (попытка $i): $STATUS"
    fi
done

if [[ "$CONNECTED" != "true" ]]; then
    LOG_WARN "WARP не удалось подключить. Проверьте лог."
    # Проверим статус сервиса WARP
    if command -v systemctl >/dev/null 2>&1; then
        warp_svc_status=$(systemctl status warp-svc 2>&1 | tee -a "$LOG_FILE")
        LOG_DEBUG "Статус warp-svc: $warp_svc_status"
    fi
    # Проверим, зарегистрирован ли WARP
    registration_status=$(warp-cli registration 2>&1 | tee -a "$LOG_FILE")
    LOG_DEBUG "Статус регистрации WARP: $registration_status"
    
    # Проверим, может ли WARP получить IP-адрес
    warp_ip=$(warp-cli warp-dns addresses 2>/dev/null || echo "N/A")
    LOG_DEBUG "WARP DNS IP-адреса: $warp_ip"
    
    # Проверим сетевые интерфейсы
    interfaces=$(ip addr show 2>/dev/null | grep -E "(warp|tun)" || echo "No warp/tun interfaces found")
    LOG_DEBUG "Интерфейсы WARP: $interfaces"
else
    # Если WARP подключен, проверим статус и IP
    warp_ip=$(warp-cli warp-dns addresses 2>/dev/null || echo "N/A")
    LOG_DEBUG "WARP DNS IP-адреса: $warp_ip"
    
    # Проверим сетевые интерфейсы
    interfaces=$(ip addr show 2>/dev/null | grep -E "(warp|tun)" || echo "No warp/tun interfaces found")
    LOG_DEBUG "Интерфейсы WARP: $interfaces"
fi

# Проверка YouTube после WARP
LOG_INFO "Проверка YouTube после WARP..."
youtube_result=$(curl -4fs --connect-timeout 12 https://www.youtube.com 2>&1)
if [[ $? -eq 0 ]]; then
    LOG_OK "YouTube доступен"
else
    LOG_WARN "YouTube НЕ доступен"
    LOG_DEBUG "Ошибка при проверке YouTube: $youtube_result"
    # Проверим доступность других сайтов для диагностики
    LOG_DEBUG "Проверка доступности google.com..."
    google_result=$(curl -4fs --connect-timeout 12 https://www.google.com 2>&1)
    if [[ $? -eq 0 ]]; then
        LOG_DEBUG "google.com доступен"
    else
        LOG_DEBUG "google.com НЕ доступен: $google_result"
    fi
    
    LOG_DEBUG "Проверка DNS..."
    dns_check=$(nslookup youtube.com 2>&1)
    LOG_DEBUG "Результат nslookup для youtube.com: $dns_check"
fi

# Обновление системы
if [[ "$OS_ID" == "steamos" ]] || [[ "$OS_NAME" == *"Steam"* ]]; then
    if command -v steamos-update >/dev/null 2>&1; then
        LOG_INFO "Обновление SteamOS..."
        sudo steamos-update check 2>&1 | tee -a "$LOG_FILE" || true
        sudo steamos-update 2>&1 | tee -a "$LOG_FILE" || LOG_WARN "Обновление SteamOS с ошибками"
    fi
elif [[ "$OS_ID" == "arch" ]]; then
    LOG_INFO "Обновление Arch Linux..."
    sudo pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE" || LOG_WARN "Обновление Arch с ошибками"
fi

# Включаем readonly обратно для SteamOS
if [[ "$OS_ID" == "steamos" ]] || [[ "$OS_NAME" == *"Steam"* ]]; then
    if command -v steamos-readonly >/dev/null 2>&1; then
        sudo steamos-readonly enable 2>&1 | tee -a "$LOG_FILE" || true
    fi
fi

echo "" | tee -a "$LOG_FILE"
echo -e "${WHITE}╔════════════════════════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
echo -e "${WHITE}║${NC}  SKIP завершён                                              ${WHITE}║${NC}" | tee -a "$LOG_FILE"
echo -e "${WHITE}║${NC}  Log: ${CYAN}$LOG_FILE${NC}                                  ${WHITE}║${NC}" | tee -a "$LOG_FILE"
echo -e "${WHITE}║${NC}  Перезагрузка через 10 сек (Ctrl+C — отменить)              ${WHITE}║${NC}" | tee -a "$LOG_FILE"
echo -e "${WHITE}╚════════════════════════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
sleep 10

sudo reboot
