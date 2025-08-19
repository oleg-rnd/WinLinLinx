WinLinLinx
Script for Windows navigation shortcuts inside Linux

The script allows you to open Windows navigation shortcuts (.lnk) in Linux with the KDE (Plasma) desktop environment. It automatically extracts the path from the `.lnk` file and opens the target folder or file in the Dolphin file manager.

Цель скрипта 
- Преобразовать путь из Windows-формата (`C:\Folder\file`) в Linux-формат (`/media/userX/C/Folder/file`)
- Открыть путь в текущем окне Dolphin (если запущен) или через `xdg-open`
- Поддерживать ярлыки с **кириллицей**, **пробелами** и **сложными путями**

1. Установка lnkinfo
`lnkinfo` — утилита из проекта `libyal/liblnk`, которая извлекает информацию из `.lnk`-файлов, включая пути с кириллицей.

```bash
sudo apt update
sudo apt install liblnk-utils

Подробнее:
https://manpages.debian.org/testing/liblnk-utils/lnkinfo.1.en.html
https://github.com/libyal/liblnk

2. Настройка скрипта

Создайте файл lnk-handler.sh и вставьте туда соответственное содержимое из репозитория

в конфигурационной части:
укажите точку монтирования (MOUNT_POINT) Windows дисков к Linux-ситеме,  например  /media/userX/
и, в (declare), соответствие букв дисков-Windows и Linux-разделов
(первая буква в паре - это Windows-диски, а вторые  - Linux-раздел)

Сохраните это в /usr/local/bin/lnk-handler.sh

и сделайте файл исполняемым:
```bash
chmod +x /usr/local/bin/lnk-handler.sh.

Проверка работы скрипта в теинале:
```bash
/usr/local/bin/lnk-handler.sh "/media/userX/A/way/to/your/link.lnk"


3. Создание MIME-ассоциации 

Чтобы всё работало, нужно зарегистрировать скрипт как обработчик MIME-типа application/x-ms-shortcut.
Создайте lnk-handler.desktop файл и разместите его ~/.local/share/applications/lnk-handler.desktop
```ini
[Desktop Entry]
Name=Windows Shortcut Handler
Comment=Open Windows .lnk files in Linux
Exec=/usr/local/bin/lnk-handler.sh %f
Icon=application-x-executable
Terminal=false
Type=Application
MimeType=application/x-ms-shortcut;
NoDisplay=true

Обновите базу MIME:
```bash
update-desktop-database ~/.local/share/applications

Установите ассоциацию:
```bash
xdg-mime default lnk-handler.desktop application/x-ms-shortcut

Проверка ассоциации:
```bash
xdg-mime query default application/x-ms-shortcut

Должно вернуть: lnk-handler.desktop

4. Автозагрузка

Создайте lnk-handler.desktop файл и разместите его в ~/.config/autostart/lnk-handler-setup.desktop
```ini
[Desktop Entry]
Type=Application
Name=LNK Handler Setup
Comment=Ensures .lnk associations are loaded
Exec=/bin/true
OnlyShowIn=KDE;
X-GNOME-Autostart-Delay=5
X-GNOME-Autostart-enabled=true



5. Необходимые пояснения 

    %f в .desktop файле — это заполнитель для передачи пути к файлу в скрипт.
    NoDisplay=true — скрывает пункт из меню приложений, но оставляет его доступным для MIME-ассоциаций.
    Terminal=false — скрипт работает в фоне, терминал не открывается.
    iocharset=utf8 при монтировании NTFS — помогает корректно отображать кириллицу. Пример в /etc/fstab:

/dev/sda1 /media/ox/F ntfs-3g defaults,uid=1000,gid=1000,iocharset=utf8 0 0

Если Dolphin не открывает папку в существующем окне, он откроет новое окно — это поведение xdg-open

Ограничения

- Работает только с локальными или смонтированными сетевыми дисками (например, через `ntfs-3g`, `autofs`, `fstab`)
- Не поддерживает ярлыки на URL, Control Panel, OneDrive и другие виртуальные объекты Windows
- Требует, чтобы Windows-диски были смонтированы и доступны по известному пути
- Для корректной работы с кириллицей рекомендуется монтировать NTFS-диски с опцией `iocharset=utf8` или `utf8`
- Требует доработки для работы ярлыков текстовых файлов
