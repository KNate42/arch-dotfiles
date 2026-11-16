# План: dotfiles для Arch Linux на Hyprland

Сверка пакетов и документации — 16.11.2026 (archlinux.org/packages, AUR RPC v5, wiki.hypr.land, hypr.land/news, quickshell.org, wiki.archlinux.org/title/NVIDIA, README и пример конфига matugen).

## Главное, что выяснилось при сверке

1. **Hyprland теперь настраивается на Lua.** С 0.55 основной конфиг — `~/.config/hypr/hyprland.lua` (`hl.bind`, `hl.monitor`, `hl.env`, `hl.on`). Старый `hyprland.conf` поддерживается «1–2 релиза после 0.55», в extra уже 0.57.2. Пишу сразу на Lua. Модульность бесплатная: каждый `require` в Hyprland — отдельная область, ошибка в одном файле не роняет остальные.
2. hyprlock и hypridle остаются на старом синтаксисе hyprlang (`*.conf`).
3. **swww переименован в awww** (extra/awww 0.12.1, `replaces swww`). Команды: `awww-daemon`, `awww img`.
4. **quickshell и matugen — в официальном extra**, AUR не нужен.
5. Страница Nvidia в wiki Hyprland теперь только отсылает к Arch Wiki. По Arch Wiki: `nvidia_drm modeset` и `fbdev` уже включены по умолчанию в nvidia-utils (с 560.35.03-5). **Параметры ядра для Hyprland больше не обязательны**, загрузчик можно вообще не трогать.
6. Подключение телевизора ловится прямо в Lua-конфиге: события `monitor.added` / `monitor.removed`. Отдельный демон с socat не нужен.
7. rofi 2.x в extra, пакета `rofi-wayland` больше нет. Наличие проверено; то, что Wayland в 2.x встроен, перепроверю по changelog на этапе Hyprland.

## (а) Дерево репозитория

```
arch-dotfiles/
├── install.sh                  # только разбор флагов и запуск модулей по очереди
├── install.d/                  # независимые шаги, каждый запускается и падает сам по себе
│   ├── 00-preflight.sh         # проверки: Arch, не root, сеть, multilib
│   ├── 05-from-iso.sh          # только для --from-iso: диск → pacstrap → chroot
│   ├── 10-base.sh              # pacman.txt (--needed)
│   ├── 15-yay.sh               # yay-bin из AUR, если yay нет
│   ├── 20-aur.sh               # aur.txt через yay
│   ├── 30-nvidia.sh            # драйвер, mkinitcpio, сервисы сна
│   ├── 35-bootloader.sh        # только после явного «да», по умолчанию пропуск
│   ├── 36-secureboot.sh        # только с --secure-boot (добавлено позже)
│   ├── 38-apparmor.sh          # AppArmor: пакет, служба, lsm= после «да» (добавлено позже)
│   ├── 40-dev.sh               # docker, postgres initdb, rustup, archlinux-java
│   ├── 45-security.sh          # nftables, DNS-over-TLS, MAC, sudo, coredump, сканеры (добавлено позже)
│   ├── 50-backup.sh            # бэкап того, что мешает stow
│   ├── 55-stow.sh              # stow --no-folding всех пакетов
│   ├── 60-theme.sh             # первый прогон matugen, gsettings, курсор, иконки
│   ├── 70-sddm.sh              # своя тема SDDM в /usr/share/sddm/themes
│   └── 80-services.sh          # NetworkManager, bluetooth, sddm, pipewire (user)
├── lib/
│   ├── ui.sh                   # только чистые функции: say, oops, run_cmd, ask_yes
│   └── bootloader.sh           # правка параметров ядра для 35 и 38
├── packages/
│   ├── pacman.txt
│   └── aur.txt
├── hypr/.config/hypr/
│   ├── hyprland.lua            # только require модулей
│   ├── modules/
│   │   ├── env.lua             # переменные Nvidia, Qt, курсор
│   │   ├── monitors.lua        # основной монитор + правило для ТВ + события hotplug
│   │   ├── input.lua           # us,ru, переключение раскладки
│   │   ├── look.lua            # отступы, рамки, анимации
│   │   ├── binds.lua           # все хоткеи
│   │   ├── rules.lua           # правила окон
│   │   └── autostart.lua       # awww-daemon, quickshell, hypridle, polkit
│   ├── hyprlock.conf
│   └── hypridle.conf
├── quickshell/.config/quickshell/
│   ├── shell.qml               # только подключает модули
│   ├── theme/Colors.qml        # читает сгенерированный colors.json, следит за файлом
│   ├── bar/                    # воркспейсы, часы, раскладка, звук, сеть, трей
│   ├── notifications/          # демон уведомлений (Quickshell.Services.Notifications)
│   ├── osd/                    # громкость и яркость
│   └── wallpaper/              # окно выбора обоев для Super+W
├── kitty/.config/kitty/kitty.conf
├── fish/.config/fish/{config.fish, conf.d/, functions/}
├── starship/.config/starship.toml
├── rofi/.config/rofi/{config.rasi, theme.rasi}
├── matugen/.config/matugen/
│   ├── config.toml             # [templates.*]: input_path, output_path, post_hook
│   └── templates/              # kitty, rofi, quickshell, gtk3/4, qt6ct, hyprlock, hyprland.lua, sddm
├── gtk/.config/{gtk-3.0,gtk-4.0}/settings.ini
├── qt/.config/qt6ct/qt6ct.conf
├── nvim/.config/nvim/          # init.lua + lua/plugins/*
├── scripts/.local/bin/
│   ├── wallpaper-set           # awww img + matugen image + перезагрузка программ
│   ├── screenshot-area         # grim + slurp + wl-copy
│   └── tv-audio                # переключение звука на HDMI телевизора
├── wallpapers/                 # 3–4 обоев со свободной лицензией
├── sddm-theme/                 # QML-тема входа, ставится 70-sddm.sh
├── tests/                      # проверки в Docker-контейнере archlinux
├── docs/screenshots/           # заглушки под скриншоты
└── README.md
```

Почему так:
- **Без мастер-файла.** `install.sh` не хранит состояния: перебирает `install.d/*.sh`, каждый запускает отдельным процессом с теми же флагами, упавшие собирает в список и показывает в конце. Любой модуль можно запустить сам: `./install.d/30-nvidia.sh --dry-run`.
- `lib/ui.sh` — общий, но без глобального состояния: в нём только функции вывода и `run_cmd`; флаг `--dry-run` каждый модуль разбирает сам.
- `stow --no-folding`: в `~/.config/kitty` и других папках ссылками становятся только файлы, а не вся папка. Так сгенерированные matugen файлы не попадают в репозиторий.

## (б) Этапы и как проверить каждый

У меня нет Arch и Nvidia. Проверяю в Docker-контейнере `archlinux:latest` (официальный образ). Docker на машине есть; shellcheck, luac и qmllint ставятся внутри контейнера, Windows не трогаю. Живой Hyprland, GPU, SDDM и телевизор проверить без железа нельзя — это проверка владельца на первой загрузке.

| Этап | Что делаю | Как проверяю |
|---|---|---|
| 1. База | скелет репо, `lib/ui.sh`, `packages/*.txt`, kitty, fish, starship, nvim | `pacman -Sp --needed $(cat pacman.txt)` в контейнере разрешает все имена; AUR-имена через RPC; `fish -n` на всех .fish; nvim headless `+qa` без ошибок |
| 2. Hyprland | `hyprland.lua` и модули, hyprlock, hypridle, скрипты скриншота и ТВ | `luac -p` на всех .lua; сверка каждого `hl.*` с wiki версии 0.57 и стабами `/usr/share/hypr/stubs`; таблица хоткеев против задания |
| 3. Quickshell | бар, уведомления, OSD, выбор обоев | `qmllint` с модулями Quickshell; запуск `quickshell` в контейнере под headless Wayland (если поднимется, честно скажу, если нет) |
| 4. Темизация | matugen-шаблоны для kitty, rofi, Quickshell, GTK, Qt, hyprlock, Hyprland, SDDM; `wallpaper-set` | `matugen image wallpapers/x.jpg` в контейнере: все выходные файлы созданы, синтаксис валиден (`luac -p`, разбор JSON, kitty `--debug-config`); смена картинки меняет цвета |
| 5. install.sh | модули `install.d/*`, `--dry-run`, `--from-iso` | `shellcheck -x` без замечаний; в контейнере: dry-run ничего не меняет (сравнение хешей), реальный прогон, повторный прогон — без изменений и без ошибок; бэкап конфликтующего файла |
| 6. README | установка, хоткеи, обои, ТВ, откат | ссылки и команды из README совпадают с файлами; заглушки скриншотов на месте |

## (в) Пакеты

Все — проверено 16.11.2026, кроме отмеченного.

**pacman (core/extra/multilib):**
- Оболочка: `hyprland` 0.57.2, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `hyprpolkitagent`, `hyprland-qt-support`, `hyprlock`, `hypridle`, `qt5-wayland`, `qt6-wayland`
- Панель и темы: `quickshell` 0.3.2, `matugen` 4.2.0, `awww` 0.12.1, `rofi` 2.1.1, `adw-gtk-theme`, `qt6ct`, `qt5ct`, `nwg-look`, `papirus-icon-theme`, `ttf-jetbrains-mono-nerd`, `noto-fonts-emoji`, `noto-fonts-cjk`
- Терминал: `kitty`, `fish`, `starship`
- Утилиты: `grim`, `slurp`, `wl-clipboard`, `cliphist`, `libnotify`, `jq`, `inotify-tools`, `brightnessctl`, `pavucontrol`, `xdg-user-dirs`, `stow`
- Звук, сеть: `pipewire`, `pipewire-pulse`, `wireplumber`, `networkmanager`, `bluez`, `bluez-utils`
- Вход: `sddm` 0.21.0 (под вопросом: собрана ли она на Qt6 и нужны ли `qt6-svg`, `qt6-5compat` для своей темы — проверю на этапе SDDM)
- Nvidia: `nvidia-open-dkms` 620.70.06, `nvidia-utils`, `lib32-nvidia-utils` (multilib), `nvidia-settings`, `egl-wayland`, `libva-nvidia-driver`, `linux-headers`, `dkms`. GTX 1660 Super — Turing, Arch Wiki для неё рекомендует open-модули.
- Dev: `neovim`, `docker`, `docker-compose`, `docker-buildx`, `nodejs`, `npm`, `python`, `postgresql`, `rustup`
- Java — все варианты из extra: `jdk-openjdk` (27), `jdk21-openjdk`, `jdk17-openjdk`, `jdk11-openjdk`, `jdk8-openjdk`. Переключение — `archlinux-java` (под вопросом: сама команда идёт с `java-runtime-common`, проверю зависимость)
- Rust: `rustup`, а не `rust` — они конфликтуют. Потом `rustup default stable` от пользователя.
- Для `--from-iso`: `arch-install-scripts`, `btrfs-progs`, `gptfdisk`, `efibootmgr` (на образе уже есть)

**AUR:**
- `yay-bin` 13.1.0 (ставлю `-bin`, чтобы не тянуть Go)
- `bibata-cursor-theme-bin` 2.0.7
- VS Code: в extra есть `code` 1.138 (открытая сборка, магазин Open VSX); в AUR — `visual-studio-code-bin` 1.146 (сборка Microsoft, их магазин расширений). **Под вопросом** — вопрос 3.
- SDDM-тема: в AUR есть `sddm-astronaut-theme`, `sddm-sugar-candy-git`, `catppuccin-sddm-theme-mocha`, но ни одна не берёт цвета из matugen. Предлагаю свою QML-тему в репо — тогда AUR не нужен.

## (г) Решения

**--dry-run.** Каждое изменяющее действие идёт через `run_cmd`: при `--dry-run` печатает команду с пометкой `[dry-run]` и не выполняет. Чтения (проверки «уже стоит?») выполняются всегда, поэтому dry-run показывает не весь список, а только то, что реально изменится. Разметка диска в dry-run только печатает план разделов.

**Бэкап.** `50-backup.sh` спрашивает у stow список конфликтов (`stow -n -v`), переносит только реальные файлы, которые мешают, в `~/.config-backup-ГГГГММДД-ЧЧММСС/` с сохранением путей. Ссылки, уже указывающие в репо, не трогает. Нечего бэкапить — папка не создаётся. Откат описан в README.

**Идемпотентность.** `pacman -S --needed`, `yay -S --needed`; перед каждой правкой файла — проверка, есть ли уже нужная строка; `stow --restow`; `initdb` только если нет `/var/lib/postgres/data/PG_VERSION`; `usermod -aG docker` только если пользователя нет в группе; `systemctl enable` безопасен при повторе. Повторный запуск в тестах обязан выдать «ничего не изменилось».

**Пути и пользователь.** Путь к репо — из `$(dirname "$(realpath "$0")")`, пользователь — `$USER` и `$HOME`. Скрипт отказывается работать от root (кроме режима ISO), sudo просит сам.

**Nvidia** (`30-nvidia.sh`):
- `nvidia-open-dkms`, `nvidia-utils`, `lib32-nvidia-utils`, `egl-wayland`, `libva-nvidia-driver`, заголовки для каждого установленного ядра (`linux` → `linux-headers`, `linux-lts` → `linux-lts-headers`);
- проверка после установки: `/sys/module/nvidia_drm/parameters/modeset` = `Y`;
- ранняя загрузка модулей `nvidia nvidia_modeset nvidia_uvm nvidia_drm` в `/etc/mkinitcpio.conf` и убрать хук `kms` (чтобы nouveau не попал в initramfs) — по Arch Wiki это по желанию, ставлю с подтверждением, затем `mkinitcpio -P`;
- службы `nvidia-suspend/resume/hibernate` не включаю: с драйвера 595 сон идёт через ядро (Arch Wiki);
- в `env.lua`: `LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `NVD_BACKEND=direct`. Каждую переменную ещё раз сверю с Arch Wiki на этапе Hyprland.

**Загрузчик.** Раз modeset уже включён по умолчанию, параметры ядра не нужны. `35-bootloader.sh` по умолчанию пропускается. Если владелец сам захочет добавить, например, `nvidia_drm.modeset=1` явно: модуль определяет загрузчик (systemd-boot `/boot/loader/entries`, Limine `limine.conf`, GRUB `/etc/default/grub`), показывает дифф, делает копию `.bak` и меняет только после ввода `да`. Неизвестный загрузчик — «Ooops..» и пропуск.

**Режим ISO (`install.sh --from-iso`).** Как я это вижу:
1. Запуск с образа: `pacman -Sy git`, `git clone`, `./install.sh --from-iso`.
2. Показывает `lsblk -o NAME,SIZE,MODEL,SERIAL`, просит **ввести имя диска руками** (например, `nvme0n1`), потом ещё раз ввести его же для подтверждения. Диск с разделами Windows (NTFS / `Microsoft reserved`) — отдельное громкое предупреждение.
3. GPT: EFI 1 ГиБ (FAT32) + btrfs на остальное; подтома `@`, `@home`, `@log`, `@pkg`, `@snapshots`, `compress=zstd`.
4. `pacstrap` минимальной базы (`base linux linux-headers linux-firmware btrfs-progs networkmanager sudo git`, микрокод по процессору), `genfstab -U`.
5. В `arch-chroot`: локаль, часовой пояс, hostname, пользователь с паролем (спрашивает), sudo для группы wheel, systemd-boot.
6. Копирует репо в `/home/<пользователь>/arch-dotfiles`, а остальное (пакеты, yay, Nvidia, stow) запускает внутри chroot от имени пользователя (`runuser -u`). Не сработает — после перезагрузки тот же `./install.sh` доделает, идемпотентность это позволяет.

Риски честно:
- Неверно введённое имя диска сотрёт его. Защита — ручной ввод дважды и проверка на Windows, но последняя линия — внимание владельца.
- Dual boot с Windows: если Windows на другом диске, systemd-boot его сам не увидит без копирования EFI-загрузчика Windows; если на том же — этот режим не подходит вовсе (он размечает весь диск).
- Сборка AUR и dkms в chroot обычно работает, но ошибки возможны; старый keyring на образе лечится `pacman -Sy archlinux-keyring` первым шагом.
- Secure Boot нужно выключить (неподписанные модули Nvidia).
- Проверить это я могу только по коду и в контейнере; настоящую установку — нет. Безопасный прогон — виртуальная машина с образом Arch, но это требует включить Hyper-V или поставить QEMU, а это решение владельца.
- **Рекомендация:** держать `--from-iso` как удобство, а основной путь в README — archinstall (btrfs, systemd-boot, пользователь) → перезагрузка → `./install.sh`. Он проверен тысячами людей.

**matugen-шаблоны.** `~/.config/matugen/config.toml`, секции `[templates.<имя>]` с `input_path`, `output_path`, `post_hook` (проверено по примеру конфига matugen). Шаблоны и куда пишут:
- kitty → `~/.config/kitty/colors.conf`, перезагрузка `kill -SIGUSR1` всем kitty;
- rofi → `~/.config/rofi/colors.rasi`, подхватится при следующем запуске;
- Quickshell → `~/.cache/matugen/colors.json`, `Colors.qml` следит за файлом и меняется на лету;
- GTK 3/4 → `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css` поверх `adw-gtk3`;
- Qt → `~/.config/qt6ct/colors/matugen.conf`;
- hyprlock → `~/.config/hypr/colors.conf`, подключается через `source`;
- Hyprland → `~/.config/hypr/modules/colors.lua` (цвета рамок), Hyprland перечитывает конфиг сам при изменении файла;
- SDDM → файл в `/var/lib/sddm-matugen/`, папку создаёт install.sh с правами пользователя, тема читает её. Под вопросом: позволит ли SDDM теме читать файл вне своей папки — проверю, запасной вариант — ссылка `theme.conf.user` на этот файл.

Сгенерированные файлы в git не попадают (`--no-folding` + `.gitignore`).

**Super+W.** Открывает выбор обоев в Quickshell (сетка миниатюр из `~/Pictures/wallpapers`), выбор вызывает `wallpaper-set <файл>`: `awww img` с переходом → `matugen image <файл>` → хуки перезагружают программы → копия картинки для SDDM и hyprlock. Тот же скрипт работает из терминала.

**Телевизор Samsung.** В `monitors.lua`: правило для основного монитора, правило по описанию ТВ (`desc:Samsung ...`, точную строку владелец берёт из `hyprctl monitors all`) и общее правило `output = ""` на всякий случай. В `hl.on("monitor.added")` / `"monitor.removed"`: уведомление, перенос заданных воркспейсов на ТВ и обратно, по желанию переключение звука на HDMI через `wpctl`. Без телевизора и Nvidia проверить нельзя: проверю только синтаксис и логику по документации.

**Стиль кода.** Шапка в каждом скрипте: что делает файл и `This work made by Anfinogentov Nikita`. Функции и переменные — строчными через `_`. Комментарии в конфигах по-русски, от первого лица и только там, где неочевидно. Ошибки — «Ooops.. …». В QML и Lua имена API (`hl.bind`, `PanelWindow`) остаются как в документации, своё — в том же стиле.

## (д) Решения владельца (16.11.2026)

1. Блокировка — Super+Escape; Super+H/J/K/L — фокус, Super+L — фокус вправо.
2. Телевизор: расширять экран (ТВ справа, воркспейсы 6–9), звук на HDMI при подключении и обратно при отключении.
3. VS Code — visual-studio-code-bin из AUR.
4. Arch один на новом NVMe, без Windows и двойной загрузки; --from-iso размечает весь диск.
5. Java по умолчанию — 21; остальные версии тоже ставятся, переключение через archlinux-java (пакет java-runtime-common).

6. Безопасность (добавлено 16.11.2026): модуль `45-security` (nftables, DNS-over-TLS, случайный MAC Wi-Fi, таймаут sudo, без дампов памяти, сканеры по требованию, проверка PKGBUILD из AUR), `38-apparmor` (AppArmor в основной установке), `36-secureboot` (по флагу). Шифрование диска LUKS не делаем — решение владельца.

Поправки после аудита плана: службы nvidia-suspend/resume/hibernate не включаются (с драйвера 595 они штатно выключены); вместо проверки /sys в chroot — проверка сборки DKMS. Подробности — в PROGRESS.md.
