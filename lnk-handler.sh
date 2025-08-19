#!/bin/bash

# Конфигурация
MOUNT_POINT="/media/uname/"
declare -A DRIVE_MAP=(
    ["A"]="A"
    ["B"]="B"
    ["D"]="D"
    ["C"]="C"
    ["E"]="E"
    ["F"]="F"
)

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка аргументов
LNK_FILE="$1"
[ -z "$LNK_FILE" ] && { log_error "Не передан файл. Использование: $0 <файл.lnk>"; exit 1; }
[ ! -f "$LNK_FILE" ] && { log_error "Файл не существует: $LNK_FILE"; exit 1; }
[[ ! "$LNK_FILE" =~ \.lnk$ ]] && { log_error "Файл не имеет расширения .lnk"; exit 1; }

log_info "Обработка ярлыка: $LNK_FILE"

# Функция извлечения полного пути
extract_full_windows_path() {
    if ! command -v lnkinfo >/dev/null; then
        log_error "Требуется утилита lnkinfo"
        return 1
    fi

    local raw_info=$(lnkinfo "$LNK_FILE" 2>/dev/null)
    local drive=$(echo "$raw_info" | grep -oP "Volume name\s*:\s*\K[A-Z]:" | head -1)
    local path_components=$(echo "$raw_info" | grep -oP "Long name\s*:\s*\K[^[:space:]].*")
    
    local full_path="$drive"
    while IFS= read -r component; do
        full_path="${full_path}\\${component}"
    done <<< "$path_components"
    
    echo "$full_path" | tr -d '\r'
}

# Получаем Windows-путь
TARGET_PATH=$(extract_full_windows_path)
[ -z "$TARGET_PATH" ] && { log_error "Не удалось извлечь путь из ярлыка"; exit 1; }
log_ok "Извлечен Windows путь: $TARGET_PATH"

# Нормализация пути (сохраняем ведущий слэш)
normalize_path() {
    local path="$1"
    path=$(echo "$path" | tr '\\' '/' | sed 's#//\+#/#g')
    path="${path%/}"
    [[ "$path" != /* ]] && path="/$path"
    echo "$path"
}

# Преобразование в Linux-путь
DRIVE_LETTER=$(echo "$TARGET_PATH" | cut -c1 | tr '[:lower:]' '[:upper:]')
REMAINING_PATH=$(echo "$TARGET_PATH" | cut -d':' -f2-)
REMAINING_PATH=$(normalize_path "$REMAINING_PATH")

[ -z "${DRIVE_MAP[$DRIVE_LETTER]}" ] && {
    log_error "Нет сопоставления для диска '$DRIVE_LETTER'"
    log_warn "Доступные диски: ${!DRIVE_MAP[@]}"
    exit 1
}

LINUX_DRIVE="${DRIVE_MAP[$DRIVE_LETTER]}"
FULL_LINUX_PATH="${MOUNT_POINT}${LINUX_DRIVE}/${REMAINING_PATH}"
FULL_LINUX_PATH=$(normalize_path "$FULL_LINUX_PATH")

# Проверка и поиск существующего пути
find_existing_path() {
    local path="$1"
    while [ "$path" != "/" ] && [ ! -e "$path" ]; do
        path=$(dirname "$path")
    done
    echo "$path"
}

FINAL_PATH=$(find_existing_path "$FULL_LINUX_PATH")

# Если ничего не найдено, используем точку монтирования
if [ ! -e "$FINAL_PATH" ]; then
    FINAL_PATH="${MOUNT_POINT}${LINUX_DRIVE}"
    [ ! -d "$FINAL_PATH" ] && FINAL_PATH="/"
fi

# Формируем правильный абсолютный путь
FINAL_PATH=$(realpath -m "$FINAL_PATH")

if [ "$FINAL_PATH" != "$FULL_LINUX_PATH" ]; then
    log_warn "Путь не существует: $FULL_LINUX_PATH"
    log_warn "Открываю существующую директорию: $FINAL_PATH"
fi

log_ok "Конечный путь: $FINAL_PATH"

# Функция для открытия в текущем окне Dolphin
open_in_current_dolphin() {
    local path="$1"
    
    # Получаем DBus-адрес активного окна Dolphin
    local dolphin_service=$(qdbus | grep -m1 'org.kde.dolphin')
    
    if [ -n "$dolphin_service" ]; then
        # Открываем в текущей вкладке (не создавая новую)
        qdbus "$dolphin_service" /dolphin/Dolphin_1 org.kde.dolphin.MainWindow.openDirectories "[\"$path\"]" true
        return $?
    fi
    
    return 1
}

# Обновленная функция open_path
open_path() {
    local path="$1"
    
    if [ ! -e "$path" ]; then
        log_error "Путь не существует: $path"
        return 1
    fi

    if [ ! -r "$path" ]; then
        log_error "Нет прав доступа к пути: $path"
        return 1
    fi

    # Сначала пробуем открыть в текущем окне Dolphin
    if command -v qdbus >/dev/null && open_in_current_dolphin "$path"; then
        log_ok "Открыто в текущем окне Dolphin: $path"
        return 0
    fi

    # Если не получилось, пробуем стандартный способ (новое окно)
    if command -v dolphin >/dev/null; then
        dolphin "$path" >/dev/null 2>&1 &
        log_warn "Открыто в новом окне Dolphin (резервный режим)"
        return 0
    fi

    # Фолбэк на xdg-open
    if command -v xdg-open >/dev/null; then
        xdg-open "$path" >/dev/null 2>&1
        log_warn "Открыто через xdg-open (резервный режим)"
        return 0
    fi

    log_error "Не удалось открыть путь"
    return 1
}

# Открываем путь
open_path "$FINAL_PATH"
exit $?
