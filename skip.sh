#!/bin/bash

# ================== ASCII ==================
cat <<'EOF'
___/\/\/\/\/\__/\/\____/\/\__/\/\/\/\__/\/\/\/\/\____/\/\____/\/\__/\/\/\/\/\____/\/\/\/\/\________/\/\______/\/\/\/\/\/\__/\/\/\/\/\/\__/\/\____/\_
_/\/\__________/\/\__/\/\______/\/\____/\/\____/\/\__/\/\____/\/\__/\/\____/\/\__/\/\____/\/\____/\/\/\/\________/\/\__________/\/\______/\/\____/\_
___/\/\/\/\____/\/\/\/\________/\/\____/\/\/\/\/\____/\/\____/\/\__/\/\/\/\/\____/\/\____/\/\__/\/\____/\/\______/\/\__________/\/\________/\/\/\/\_
_________/\/\__/\/\__/\/\______/\/\____/\/\__________/\/\____/\/\__/\/\__________/\/\____/\/\__/\/\/\/\/\/\______/\/\__________/\/\__________/\_
_/\/\/\/\/\____/\/\____/\/\__/\/\/\/\__/\/\____________/\/\/\/\____/\/\__________/\/\/\/\/\____/\/\____/\/\______/\/\__________/\/\__________/\_
_________________________________________________________________________________________________________________________________________________
EOF

echo "Запуск установки ZapretDeck..."

# Определяем ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$NAME"
    OS_ID="$ID"
    echo "Определена ОС: $OS_NAME ($OS_ID)"
else
    OS_ID="unknown"
    echo "Не удалось определить ОС"
fi

IS_STEAMOS=false
if [[ "$OS_ID" == "steamos" || "$OS_NAME" == *"SteamOS"* ]]; then
    IS_STEAMOS=true
    echo "Определена SteamOS. Старт установки..."
fi

# Переходим в Downloads
mkdir -p ~/Downloads
cd ~/Downloads || { echo "Ошибка: нет доступа к ~/Downloads"; exit 1; }

# Создаём отдельную папку для установщика
mkdir -p zapretdeck
cd zapretdeck

# Отключаем защиту от записи SteamOS
if [ "$IS_STEAMOS" = true ]; then
    echo "Отключаем защиту от записи SteamOS..."
    sudo steamos-readonly disable || { echo "Ошибка отключения readonly"; exit 1; }
fi

# Скачиваем архив
curl -L -o ZapretDeck_v0.2.0.tar.gz "https://github.com/rosakodu/zapretdeck/releases/download/v.0.2.0/ZapretDeck_v0.2.0.tar.gz" || { echo "Ошибка скачивания"; exit 1; }

# Распаковываем архив
tar -xzf ZapretDeck_v0.2.0.tar.gz --strip-components=1

# Удаляем архив
rm ZapretDeck_v0.2.0.tar.gz

# Делаем скрипт исполняемым
chmod +x install.sh

# Запускаем установку
echo "Установка ZapretDeck..."
sudo ./install.sh || { echo "Ошибка установки ZapretDeck"; exit 1; }

# Полный запуск обхода
zapretdeck full start || echo "Предупреждение: команда запуска не выполнена (возможно, требует ручного запуска)"

# Возвращаем защиту записи SteamOS
if [ "$IS_STEAMOS" = true ]; then
    echo "Включаем защиту от записи SteamOS..."
    sudo steamos-readonly enable
fi

# Очищаем
cd ..
rm -rf zapretdeck

echo "Установка ZapretDeck завершена!"

# Дополнительные функции для SteamOS
if [ "$IS_STEAMOS" = true ]; then
    echo "Запускаем обновление Flatpak на SteamOS..."
    flatpak update -y

    echo "Проверяем обновления SteamOS..."
    if sudo steamos-update check; then
        echo "Обновление SteamOS доступно. Обновляем..."
        sudo steamos-update
        echo "SteamOS обновлена. Перезагрузка через 5 секунд..."
        sleep 5
        sudo reboot
    else
        echo "Обновление SteamOS не требуется"
    fi
fi
