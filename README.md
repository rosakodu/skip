# SKIP

Загрузка Steam Deck напрямую в Desktop Mode (KDE Plasma), минуя Game Mode.
Безопасное, официальное решение с использованием инструментов SteamOS.

English version below

SKIP — это простой и безопасный скрипт для Steam Deck, который позволяет загружать SteamOS сразу в рабочий стол (KDE Plasma), минуя игровой режим (Game Mode).

Проект использует официальный механизм SteamOS (steamos-session-select), не отключает системные сервисы, не изменяет systemd и не ломает обновления системы.

Скрипт рассчитан на запуск из TTY и идеально подходит для пользователей, которым важно сначала попасть в Desktop Mode — например, для настройки VPN, zapret, прокси или других системных утилит.

## ✨ Возможности

- Загрузка Steam Deck напрямую в Desktop Mode
- Без отключения Game Mode — только смена режима по умолчанию
- Безопасно для обновлений SteamOS
- Не требует отключения read-only режима
- Работает из TTY одной командой
- Лёгкий откат обратно в игровой режим

## ⚙️ Как это работает

SteamOS поддерживает выбор режима загрузки через встроенную утилиту `steamos-session-select`.

Скрипт просто устанавливает Desktop Mode (plasma) как сессию по умолчанию.
Game Mode при этом остаётся доступен и может быть возвращён в любой момент.

## 🔄 Возврат в игровой режим
```bash
steamos-session-select gamescope
```

## ⚠️ Примечание

Проект не отключает и не ломает Game Mode.
Он лишь меняет стартовый режим загрузки, используя официальные инструменты Valve.

## 📋 Установка

### Установка через TTY
```bash
curl -fsSL https://raw.githubusercontent.com/rosakodu/SKIP/main/install.sh | bash
```

### Что делает скрипт
- Устанавливает Desktop Mode как сессию по умолчанию
- Использует официальные инструменты SteamOS
- Безопасен для обновлений SteamOS
- Не использует хаки с systemd

## 📌 Важно

- Требуется перезагрузка после установки
- Использует только официальные механизмы SteamOS
- Не отключает системные службы
- Не изменяет systemd
- Безопасен для обновлений SteamOS

## 🛠️ Удаление

Чтобы вернуть Game Mode как режим по умолчанию:
```bash
./uninstall.sh
```
или вручную выполните:
```bash
steamos-session-select gamescope
```

---

# English Version

# SKIP

Boot Steam Deck directly into Desktop Mode (KDE Plasma), skipping Game Mode.
Safe, official, TTY-friendly solution using SteamOS tools.

SKIP is a simple and safe script for Steam Deck that allows SteamOS to boot directly into desktop (KDE Plasma), bypassing Game Mode.

The project uses the official SteamOS mechanism (steamos-session-select), does not disable system services, does not modify systemd, and does not break system updates.

The script is designed to run from TTY and is ideal for users who need to get to Desktop Mode first - for example, to set up VPN, zapret, proxy, or other system utilities.

## ✨ Features

- Boot Steam Deck directly into Desktop Mode
- Without disabling Game Mode - only changing the default mode
- Safe for SteamOS updates
- Does not require disabling read-only mode
- Works from TTY with a single command
- Easy rollback to Game Mode

## ⚙️ How it works

SteamOS supports boot session selection via the built-in utility `steamos-session-select`.

The script simply sets Desktop Mode (plasma) as the default session.
Game Mode remains available and can be restored at any time.

## 🔄 Return to Game Mode
```bash
steamos-session-select gamescope
```

## ⚠️ Note

The project does not disable or break Game Mode.
It only changes the startup boot mode, using official Valve tools.

## 📋 Installation

### Direct TTY Installation
```bash
curl -fsSL https://raw.githubusercontent.com/rosakodu/SKIP/main/install.sh | bash
```

### What this does
- Sets Desktop Mode as the default session
- Uses official SteamOS tools
- Safe for SteamOS updates
- No systemd hacks

## 📌 Important

- Reboot required after installation
- Uses official SteamOS mechanisms only
- Does not disable system services
- Does not modify systemd
- Safe for SteamOS updates

## 🛠️ Uninstall

To revert to Game Mode as default:
```bash
./uninstall.sh
```
or manually run:
```bash
steamos-session-select gamescope
```
