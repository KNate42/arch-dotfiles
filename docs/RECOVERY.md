# Памятка по восстановлению (офлайн)

Эта инструкция лежит прямо в репозитории (`~/arch-dotfiles/docs/RECOVERY.md`), чтобы её можно было прочитать из текстовой консоли без интернета:

```bash
setfont cyr-sun16
less ~/arch-dotfiles/docs/RECOVERY.md
```

В системе также есть скрипт быстрой помощи `dots-recover` (лежит в `~/.local/bin/dots-recover` или `~/arch-dotfiles/scripts/.local/bin/dots-recover`):

```bash
dots-recover info     # сводка: dkms status, nvidia-smi, systemctl --failed, aa-enabled, resolvectl status
dots-recover nosddm   # отключить SDDM и выйти в текстовую консоль
dots-recover dns      # вернуть обычный DNS от роутера через NetworkManager (без DNS-over-TLS)
```

---

## 1. Система не загружается

### Вариант А. Через запись rescue в меню systemd-boot

1. При включении компьютера удерживайте клавишу `Space` (пробел), чтобы открыть меню `systemd-boot`.
2. Выберите резервную запись **rescue** — она загрузит систему в текстовую консоль (`systemd.unit=multi-user.target`) без новых параметров ядра:
   - после `archinstall` основная запись называется по дате установки (например, `2026-11-17_05-22-56_linux.conf`), а резервная — `2026-11-17_05-22-56_linux-rescue.conf`;
   - после `--from-iso` основная запись — `arch.conf`, а резервная — `arch-rescue.conf`.
3. **Если проблема в драйвере Nvidia (DKMS) или образе загрузки:**
   Проверьте статус модулей DKMS, соберите их для каждого ядра из `/usr/lib/modules`, убедитесь, что модуль встал (`installed`), и пересоберите initramfs:

```bash
dkms status
ls /usr/lib/modules
# Для каждого ядра из вывода ls /usr/lib/modules (например, 6.12.1-arch1-1):
sudo dkms autoinstall -k <версия>
dkms status
sudo mkinitcpio -P
```

4. **Если проблема началась после правки параметров ядра (например, для AppArmor или Nvidia):**
   Посмотрите файлы в каталоге записей загрузчика:

```bash
ls /boot/loader/entries/
```

   - **Если рядом есть резервная копия `<имя>.conf.bak-ГГГГММДД-ЧЧММСС`:**
     Выберите конкретную (самую свежую по дате и времени в конце имени) копию и скопируйте её поверх основной записи, явно указав оба имени (не используйте шаблон `*`, иначе при нескольких копиях `cp` завершится ошибкой):

```bash
# Пример после archinstall (подставьте свои имена из ls /boot/loader/entries/):
sudo cp /boot/loader/entries/2026-11-17_05-22-56_linux.conf.bak-20261117-053012 \
        /boot/loader/entries/2026-11-17_05-22-56_linux.conf

# Пример после --from-iso (если копия .bak создавалась):
sudo cp /boot/loader/entries/arch.conf.bak-20261117-053012 \
        /boot/loader/entries/arch.conf
```

   - **Если копии `.bak` нет (например, после `--from-iso`):**
     Верните основную запись из записи `rescue`: скопируйте `*-rescue.conf` поверх основной записи, затем откройте основную запись в редакторе, уберите из строки `options` параметр `systemd.unit=multi-user.target` (иначе система всегда будет грузиться в текстовую консоль) и добавьте нужные параметры:

```bash
# Пример после --from-iso:
sudo cp /boot/loader/entries/arch-rescue.conf /boot/loader/entries/arch.conf
sudo nano /boot/loader/entries/arch.conf

# Пример после archinstall:
sudo cp /boot/loader/entries/2026-11-17_05-22-56_linux-rescue.conf \
        /boot/loader/entries/2026-11-17_05-22-56_linux.conf
sudo nano /boot/loader/entries/2026-11-17_05-22-56_linux.conf
```

### Вариант Б. С установочной флешки Arch Linux

Если система не доходит даже до текстовой консоли, загрузитесь с установочной флешки Arch в режиме UEFI:

```bash
setfont cyr-sun16
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

Найдите свой диск (например, `/dev/nvme0n1`, где `/dev/nvme0n1p1` — раздел EFI, монтируемый в `/boot`, а `/dev/nvme0n1p2` — раздел `btrfs`).
В штатной разметке используются подтома `@`, `@home`, `@log`, `@pkg` и подтом для снимков (`@.snapshots` после `archinstall`, `@snapshots` после `--from-iso`). Смонтируйте корневой подтом, домашний каталог, журналы (`@log`), кеш пакетов (`@pkg`) и раздел EFI, затем войдите в `arch-chroot`:

```bash
mount -o subvol=@ /dev/nvme0n1p2 /mnt
mount -o subvol=@home /dev/nvme0n1p2 /mnt/home
mount -o subvol=@log /dev/nvme0n1p2 /mnt/var/log
mount -o subvol=@pkg /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
mount /dev/nvme0n1p1 /mnt/boot
arch-chroot /mnt
```

*(Если при установке через `archinstall` вы выбрали другую разметку, сверьтесь с `/etc/fstab` установленной системы: сначала смонтируйте корень командой `mount -o subvol=@ /dev/nvme0n1p2 /mnt` или `mount /dev/nvme0n1p2 /mnt`, прочитайте файл `cat /mnt/etc/fstab` и смонтируйте разделы и подтома так, как записано в нём.)*

Внутри `arch-chroot`:

1. **Верните прежнюю запись загрузчика:**
   Посмотрите список файлов в `/boot/loader/entries/`:
   ```bash
   ls /boot/loader/entries/
   ```
   Выберите самую свежую копию `<имя>.conf.bak-ГГГГММДД-ЧЧММСС` и скопируйте её поверх основной записи с явными именами:
   ```bash
   # Пример после archinstall:
   cp /boot/loader/entries/2026-11-17_05-22-56_linux.conf.bak-20261117-053012 \
      /boot/loader/entries/2026-11-17_05-22-56_linux.conf

   # Пример после --from-iso (если копия .bak есть):
   cp /boot/loader/entries/arch.conf.bak-20261117-053012 \
      /boot/loader/entries/arch.conf
   ```
   Если копии `.bak` нет — скопируйте запись `*-rescue.conf` поверх основной (например, `cp /boot/loader/entries/arch-rescue.conf /boot/loader/entries/arch.conf`), откройте основную запись в редакторе, уберите из строки `options` параметр `systemd.unit=multi-user.target` и добавьте нужные параметры.
   *(Для GRUB копия лежит в `/etc/default/grub.bak-ГГГГММДД-ЧЧММСС` — скопируйте конкретную копию в `/etc/default/grub` и выполните `grub-mkconfig -o /boot/grub/grub.cfg`; для Limine — рядом с `limine.conf`.)*
2. **Проверьте заголовки ядра и соберите модули DKMS, затем пересоберите initramfs:**
   В `arch-chroot` команда `uname -r` показывает версию ядра флешки — **не берите её**. Посмотрите установленные ядра в `/usr/lib/modules` и выполните `dkms autoinstall -k <версия>` для каждого из них:
   ```bash
   pacman -S --needed linux-headers nvidia-open-dkms
   dkms status
   ls /usr/lib/modules
   # Для каждого ядра из /usr/lib/modules (например, 6.12.1-arch1-1):
   dkms autoinstall -k <версия>
   dkms status
   mkinitcpio -P
   ```
3. Выйдите и перезагрузитесь:
   ```bash
   exit
   umount -R /mnt
   reboot
   ```

*(Если вы включали Secure Boot со своими ключами и плата отказывается грузить ядро, временно выключите Secure Boot в настройках BIOS/UEFI.)*

---

## 2. Чёрный экран, SDDM не стартует или не входит в Hyprland

1. Переключитесь в текстовую консоль клавишами `Ctrl + Alt + F2` (или `Ctrl + Alt + F3`) и войдите под своим пользователем.
2. Отключите экран входа SDDM, чтобы он не мешал:
   ```bash
   dots-recover nosddm
   # или вручную:
   sudo systemctl disable --now sddm
   ```
3. Попробуйте запустить Hyprland напрямую из консоли:
   ```bash
   Hyprland
   ```
4. Проверьте синтаксис конфига Hyprland и сводку системы:
   ```bash
   Hyprland --verify-config --config ~/.config/hypr/hyprland.lua
   dots-recover info
   ```
5. **Где смотреть журналы ошибок:**
   - Журнал SDDM за текущую загрузку:
     ```bash
     journalctl -b -u sddm
     ```
   - Журнал последней сессии Hyprland 0.57 (хранится в `$XDG_RUNTIME_DIR/hypr/<подпись_сессии>/hyprland.log`):
     ```bash
     cat "$XDG_RUNTIME_DIR/hypr/$(ls -t "$XDG_RUNTIME_DIR/hypr/" | head -n 1)/hyprland.log"
     ```
   - Отчёты о падениях Hyprland (crash reports):
     ```bash
     ls -la ~/.cache/hyprland/ ~/.local/share/hyprland/ 2>/dev/null
     ```
   - Проверка драйвера Nvidia и KMS modeset (должно быть `Y`):
     ```bash
     cat /sys/module/nvidia_drm/parameters/modeset
     dkms status
     nvidia-smi
     ```
6. **Если модуль Nvidia не собран в DKMS (в `dkms status` нет статуса `installed`):**
   Повторная команда `pacman -S --needed` не пересобирает уже установленные пакеты. Соберите модуль вручную для каждого ядра из `/usr/lib/modules` (в `arch-chroot` не используйте `uname -r` — там это ядро флешки), проверьте `dkms status` и пересоберите образ загрузки:
   ```bash
   sudo pacman -S --needed linux-headers nvidia-open-dkms
   dkms status
   ls /usr/lib/modules
   # Для каждого ядра из /usr/lib/modules (например, 6.12.1-arch1-1):
   sudo dkms autoinstall -k <версия>
   dkms status
   sudo mkinitcpio -P
   ```

Когда проблема решена, включите SDDM обратно:

```bash
sudo systemctl enable --now sddm
```

---

## 3. Нет интернета, не открываются сайты (DNS) или страница входа в Wi-Fi

По умолчанию шаг `45-security` включает строгий **DNS-over-TLS** (`DNSOverTLS=yes`) через `systemd-resolved` (файл `/etc/systemd/resolved.conf.d/20-dns-over-tls.conf`) и отключает получение незашифрованного DNS от роутера в NetworkManager (файл `/etc/NetworkManager/conf.d/30-dns.conf`). Строгий режим не ослабляется автоматически: в сетях отелей, кафе или при блокировке порта `853/tcp` сайты и страница авторизации Wi-Fi не откроются, пока вы явно не переключите DNS.

### Диагностика

```bash
resolvectl status
ping -c 2 9.9.9.9
```

Если пинг по IP (`9.9.9.9`) идёт, а имена сайтов не открываются — дело в DNS.

### Как вернуть обычный DNS от роутера

Одной командой через помощник:

```bash
dots-recover dns
```

Или вручную:

```bash
sudo rm -f /etc/systemd/resolved.conf.d/20-dns-over-tls.conf /etc/NetworkManager/conf.d/30-dns.conf
sudo systemctl restart systemd-resolved NetworkManager
```

После этого проверьте, что доменные имена разрешаются:

```bash
resolvectl query archlinux.org
```

### Как вернуть строгий DNS-over-TLS обратно

```bash
bash ~/arch-dotfiles/install.d/45-security.sh
```

---

## 4. Установка оборвалась на полпути

Установщик спроектирован так, чтобы повторный запуск был безопасным:

- **Обычная установка (после `archinstall`):**
  Просто войдите в консоль и запустите установщик ещё раз:
  ```bash
  cd ~/arch-dotfiles
  ./install.sh
  ```
  Уже выполненные шаги он пропустит, а если сбой произошёл на переносе старых конфигов (`50-backup` или `55-stow`), автоматически вернёт унесённые файлы по журналу `~/.local/state/dots/last-backup` и разложит ссылки заново.

- **Запуск только нужных шагов:**
  Если нужно повторить один или несколько конкретных шагов (например, драйвер Nvidia, раскладку ссылок и тему):
  ```bash
  cd ~/arch-dotfiles
  ./install.sh --only 30,55,60
  # или отдельный шаг напрямую:
  bash install.d/30-nvidia.sh
  ```

- **Установка с флешки (`./install.sh --from-iso`):**
  Снова запустите `./install.sh --from-iso`. Скрипт найдёт недоделанную установку по метке `/.dots-install-stage` в подтоме `@`, спросит подтверждение имени диска и продолжит со следующей стадии **без повторной разметки и форматирования**.
