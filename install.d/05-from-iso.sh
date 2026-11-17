#!/usr/bin/env bash
# Installs Arch from the live ISO onto a whole disk (GPT: EFI + btrfs), then runs the dotfiles install inside.
# Runs only through: ./install.sh --from-iso. Wipes the chosen disk after two typed confirmations.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

mount_root="/mnt"
btrfs_opts="noatime,compress=zstd"
base_packages=(base base-devel linux linux-headers linux-firmware btrfs-progs networkmanager sudo git rsync)
# lsm = порядок модулей безопасности ядра с AppArmor; строка из Arch Wiki (AppArmor#Installation), 16.11.2026
apparmor_param="lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
sudo_temp="/etc/sudoers.d/99-dots-install"
# Флаги для установки внутри новой системы (кроме --from-iso и --dry-run), уже экранированные для shell
inner_flags=""
for flag in "$@"; do
    case "$flag" in
        --bootloader|--apparmor-d|--secure-boot|--trust-aur) inner_flags+=" $(printf '%q' "$flag")" ;;
        *) ;;
    esac
done
# Файл стадии в корне подтома @: partitioned → base → configured:<пользователь>; по нему продолжаю после сбоя
stage_file="/.dots-install-stage"

check_live_iso() {
    if [[ ! -d /run/archiso ]]; then
        oops "--from-iso работает только с установочного образа Arch (нет /run/archiso)"
        return 1
    fi
    if [[ "$EUID" -ne 0 ]]; then
        oops "на образе запускайте от root"
        return 1
    fi
    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        oops "компьютер загрузился в режиме BIOS; загрузите образ в режиме UEFI"
        return 1
    fi
    if ! curl -sfI --max-time 10 https://archlinux.org >/dev/null; then
        oops "нет интернета; для Wi-Fi сначала подключитесь через iwctl"
        return 1
    fi
}

# Здесь я не даю выбрать флешку, с которой загружен образ
iso_disk() {
    local source_dev
    source_dev="$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)"
    if [[ -n "$source_dev" ]]; then
        lsblk -no PKNAME "$source_dev" 2>/dev/null | head -n 1
    fi
}

# Принимаю только имя из показанного списка (без /dev/ и ссылок вроде /dev/disk/by-id)
choose_disk() {
    local disk
    local again
    local known=()
    mapfile -t known < <(lsblk -dn -e 7,11 -o NAME,TYPE | awk '$2 == "disk" { print $1 }')
    say "диски на этом компьютере:" >&2
    lsblk -d -e 7,11 -o NAME,SIZE,MODEL,SERIAL,TYPE >&2
    read -r -p "Имя диска для Arch из списка выше (например nvme0n1), ВСЁ на нём будет стёрто: " disk
    if [[ -z "$disk" ]] || ! printf '%s\n' "${known[@]}" | grep -qxF -- "$disk"; then
        oops "«$disk» нет в списке дисков"
        return 1
    fi
    if [[ "$disk" == "$(iso_disk)" ]]; then
        oops "/dev/$disk — это флешка с образом"
        return 1
    fi
    # Смонтированный диск не трогаю: значит, им сейчас кто-то пользуется
    if lsblk -nro MOUNTPOINTS "/dev/$disk" | grep -q .; then
        oops "на /dev/$disk есть смонтированные разделы, отмонтируйте их (umount -R /mnt) и запустите снова"
        return 1
    fi
    if lsblk -no FSTYPE,PARTTYPENAME "/dev/$disk" | grep -qiE 'ntfs|microsoft|windows'; then
        warn "НА /dev/$disk ЕСТЬ РАЗДЕЛЫ WINDOWS. Они будут уничтожены."
    fi
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "/dev/$disk" >&2
    warn "будет: стереть /dev/$disk целиком, создать EFI + btrfs, поставить Arch и загрузчик systemd-boot на этот диск"
    read -r -p "Введите имя диска ещё раз, чтобы стереть его: " again
    if [[ "$again" != "$disk" ]]; then
        oops "имена не совпали, ничего не тронуто"
        return 1
    fi
    printf '%s\n' "$disk"
}

ask_value() {
    local question="$1"
    local default="$2"
    local value
    read -r -p "$question [$default]: " value
    printf '%s\n' "${value:-$default}"
}

# Пароль спрашиваю дважды и не показываю на экране
ask_secret() {
    local question="$1"
    local min_length="$2"
    local first
    local second
    while true; do
        read -r -s -p "$question: " first
        printf '\n' >&2
        read -r -s -p "Ещё раз: " second
        printf '\n' >&2
        if (( ${#first} >= min_length )) && [[ "$first" == "$second" ]]; then
            printf '%s\n' "$first"
            return 0
        fi
        warn "пароли не совпали или короче $min_length символов, ещё раз"
    done
}

# Разделы беру у lsblk, а не дописываю номер к имени: так не важно, NVMe это или SATA
disk_partitions() {
    local disk="$1"
    lsblk -lnpo NAME,TYPE "/dev/$disk" | awk '$2 == "part" { print $1 }'
}

partition_disk() {
    local disk="$1"
    local parts=()
    local subvol

    say "стираю /dev/$disk и создаю EFI 1 ГиБ + btrfs"
    wipefs -af "/dev/$disk"
    sgdisk --zap-all "/dev/$disk"
    sgdisk -n1:0:+1G -t1:ef00 -c1:EFI -n2:0:0 -t2:8300 -c2:arch "/dev/$disk"
    partprobe "/dev/$disk"
    udevadm settle
    mapfile -t parts < <(disk_partitions "$disk")
    if (( ${#parts[@]} != 2 )); then
        oops "после разметки ожидал 2 раздела, вижу ${#parts[@]}"
        return 1
    fi
    efi_part="${parts[0]}"
    root_part="${parts[1]}"

    mkfs.fat -F 32 -n EFI "$efi_part"
    mkfs.btrfs -f -L arch "$root_part"

    mount "$root_part" "$mount_root"
    for subvol in @ @home @log @pkg @snapshots; do
        btrfs subvolume create "$mount_root/$subvol"
    done
    umount "$mount_root"

    mount_layout "$root_part" "$efi_part"
    set_stage partitioned
}

set_stage() {
    printf '%s\n' "$1" > "$mount_root$stage_file"
}

current_stage() {
    cat "$mount_root$stage_file" 2>/dev/null || true
}

# Подтома монтирую так же, как при разметке; при возобновлении — уже существующие, без mkfs
mount_layout() {
    local root_dev="$1"
    local efi_dev="$2"
    findmnt -n "$mount_root" >/dev/null 2>&1 || mount -o "$btrfs_opts,subvol=@" "$root_dev" "$mount_root"
    mkdir -p "$mount_root"/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
    findmnt -n "$mount_root/home" >/dev/null 2>&1 || mount -o "$btrfs_opts,subvol=@home" "$root_dev" "$mount_root/home"
    findmnt -n "$mount_root/var/log" >/dev/null 2>&1 || mount -o "$btrfs_opts,subvol=@log" "$root_dev" "$mount_root/var/log"
    findmnt -n "$mount_root/var/cache/pacman/pkg" >/dev/null 2>&1 || mount -o "$btrfs_opts,subvol=@pkg" "$root_dev" "$mount_root/var/cache/pacman/pkg"
    findmnt -n "$mount_root/.snapshots" >/dev/null 2>&1 || mount -o "$btrfs_opts,subvol=@snapshots" "$root_dev" "$mount_root/.snapshots"
    findmnt -n "$mount_root/boot" >/dev/null 2>&1 || mount -o fmask=0077,dmask=0077 "$efi_dev" "$mount_root/boot"
}

microcode_package() {
    if grep -q GenuineIntel /proc/cpuinfo; then
        printf 'intel-ucode\n'
    elif grep -q AuthenticAMD /proc/cpuinfo; then
        printf 'amd-ucode\n'
    fi
}

install_base() {
    local packages=("${base_packages[@]}")
    local ucode
    ucode="$(microcode_package)"
    if [[ -n "$ucode" ]]; then
        packages+=("$ucode")
    fi
    # На старом образе ключи могут устареть, поэтому сначала обновляю keyring
    pacman -Sy --noconfirm archlinux-keyring
    pacstrap -K "$mount_root" "${packages[@]}"
    # fstab пишу заново, а не дописываю: при возобновлении строки не задвоятся
    genfstab -U "$mount_root" > "$mount_root/etc/fstab"
    set_stage base
}

configure_system() {
    local hostname="$1"
    local user_name="$2"
    local timezone="$3"
    local root_uuid="$4"
    local boot_options
    boot_options="$(boot_options_for "$root_uuid")"

    arch-chroot "$mount_root" ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
    arch-chroot "$mount_root" hwclock --systohc
    sed -i -E 's/^#(en_US\.UTF-8 UTF-8)/\1/; s/^#(ru_RU\.UTF-8 UTF-8)/\1/' "$mount_root/etc/locale.gen"
    arch-chroot "$mount_root" locale-gen
    printf 'LANG=ru_RU.UTF-8\n' > "$mount_root/etc/locale.conf"
    printf 'KEYMAP=us\nFONT=cyr-sun16\n' > "$mount_root/etc/vconsole.conf"
    printf '%s\n' "$hostname" > "$mount_root/etc/hostname"

    if ! arch-chroot "$mount_root" id -u "$user_name" >/dev/null 2>&1; then
        arch-chroot "$mount_root" useradd -m -G wheel -s /bin/bash "$user_name"
    fi
    printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$mount_root/etc/sudoers.d/10-wheel"
    chmod 440 "$mount_root/etc/sudoers.d/10-wheel"
    # У root пароля нет — блокирую вход под ним совсем (Arch Wiki, sudo#Disable root login): работа через sudo
    arch-chroot "$mount_root" passwd -l root

    arch-chroot "$mount_root" bootctl install || arch-chroot "$mount_root" bootctl update
    printf 'default arch.conf\ntimeout 3\nconsole-mode max\neditor no\n' > "$mount_root/boot/loader/loader.conf"
    # Здесь я сохраняю загрузку без новых lsm/nvidia-параметров до записи основного пункта.
    if [[ ! -f "$mount_root/boot/loader/entries/arch-rescue.conf" ]]; then
        printf 'title   Arch Linux (rescue)\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img\noptions root=UUID=%s rootflags=subvol=@ rw systemd.unit=multi-user.target\n' \
            "$root_uuid" > "$mount_root/boot/loader/entries/arch-rescue.conf"
    fi
    printf 'title   Arch Linux\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img\noptions %s\n' \
        "$boot_options" > "$mount_root/boot/loader/entries/arch.conf"

    arch-chroot "$mount_root" systemctl enable NetworkManager.service
}

# Здесь я запускаю обычную установку внутри новой системы от имени пользователя.
# На время установки sudo без пароля; файл удаляется в любом случае.
# Функцию вызывают через `|| status=$?`, а там set -e не действует, поэтому каждое действие проверяю сам.
run_user_stage() {
    local user_name="$1"
    local home_repo="/home/$user_name/arch-dotfiles"
    # Служебные папки (журналы тестов, состояние инструментов) в новую систему не переношу
    if ! rsync -a --exclude '.omc/' --exclude 'tests/out/' "$repo_dir/" "$mount_root$home_repo/"; then
        oops "не смог скопировать репозиторий в $mount_root$home_repo"
        return 1
    fi
    if ! arch-chroot "$mount_root" chown -R "$user_name:$user_name" "$home_repo"; then
        oops "не смог отдать $home_repo пользователю $user_name"
        return 1
    fi

    if ! printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user_name" > "$mount_root$sudo_temp" || ! chmod 440 "$mount_root$sudo_temp"; then
        oops "не смог временно разрешить sudo без пароля"
        rm -f "$mount_root$sudo_temp"
        return 1
    fi
    trap 'rm -f "$mount_root$sudo_temp"' EXIT

    local status=0
    arch-chroot "$mount_root" runuser -l "$user_name" -c "cd '$home_repo' && DOTS_CHROOT=1 bash ./install.sh $inner_flags" || status=$?
    if ! rm -f "$mount_root$sudo_temp"; then
        oops "не смог удалить $mount_root$sudo_temp — удалите его вручную"
        return 1
    fi
    if (( status != 0 )); then
        oops "установка dotfiles внутри новой системы упала (код $status); после перезагрузки: cd ~/arch-dotfiles && ./install.sh"
        return "$status"
    fi
    rm -f "$mount_root$stage_file"
    good "dotfiles установлены в новую систему"
}

print_plan() {
    say "[dry-run] план установки с образа:"
    printf '  1. показать диски, дважды спросить имя диска из списка\n'
    printf '  2. GPT: EFI 1 GiB (FAT32) + btrfs: @ @home @log @pkg @snapshots, %s\n' "$btrfs_opts"
    printf '  3. pacstrap: %s + микрокод процессора\n' "${base_packages[*]}"
    printf '  4. показать будущую запись systemd-boot (с lsm=... для AppArmor) и спросить «да»; часовой пояс, локали en_US/ru_RU, hostname, пользователь в wheel\n'
    printf '  5. копия репо в /home/<user>/arch-dotfiles и ./install.sh внутри arch-chroot\n'
}

# Строка options для systemd-boot: AppArmor включается сразу, сам параметр владелец видит до разметки
boot_options_for() {
    printf 'root=UUID=%s rootflags=subvol=@ rw %s\n' "$1" "$apparmor_param"
}

# Перед установкой загрузчика показываю, что именно будет записано, и жду отдельного «да»
confirm_boot_config() {
    say "будущая запись загрузчика systemd-boot (/boot/loader/entries/arch.conf):" >&2
    printf '  title   Arch Linux\n  linux   /vmlinuz-linux\n  initrd  /initramfs-linux.img\n  options %s\n' \
        "$(boot_options_for '<UUID раздела btrfs>')" >&2
    say "lsm=... включает AppArmor (Arch Wiki, AppArmor#Installation)" >&2
    ask_exact "Ставить systemd-boot с такой записью?" "да"
}

# GUID типа раздела «EFI System» по спецификации UEFI: по нему отличаю ESP от любого другого vfat
esp_type="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"

# Раздел EFI на диске: только с типом ESP, первый подходящий vfat не беру
find_esp() {
    local disk="$1"
    lsblk -lnpo NAME,PARTTYPE "$disk" | awk -v esp="$esp_type" 'tolower($2) == esp { print $1; exit }'
}

# Ищу незаконченную установку: btrfs с меткой arch, на том же диске раздел ESP, в подтоме @ файл стадии.
# Пробую только на чтение (-o ro): чужой btrfs с такой же меткой ничем не рискует. Ничего не форматирую.
find_unfinished() {
    local root_dev
    local disk
    local esp_dev
    # Если /mnt остался смонтирован после сбоя, снимаю его: дальше всё монтирую заново по одной схеме
    if findmnt -n "$mount_root" >/dev/null 2>&1; then
        umount -R "$mount_root"
    fi
    while read -r root_dev disk; do
        # PKNAME у lsblk -p уже полный путь вида /dev/nvme0n1
        esp_dev="$(find_esp "$disk")"
        if [[ -z "$esp_dev" ]]; then
            continue
        fi
        mount -o "ro,subvol=@" "$root_dev" "$mount_root" 2>/dev/null || continue
        if [[ -f "$mount_root$stage_file" ]]; then
            resume_root="$root_dev"
            resume_efi="$esp_dev"
            resume_disk="$disk"
            resume_stage="$(cat "$mount_root$stage_file")"
            umount "$mount_root"
            return 0
        fi
        umount "$mount_root"
    done < <(lsblk -lnpo NAME,FSTYPE,LABEL,PKNAME | awk '$2 == "btrfs" && $3 == "arch" { print $1, $4 }')
    return 1
}

# Показываю найденный диск и прошу ввести его имя — как при разметке, только без стирания
confirm_resume() {
    say "нашёл недоделанную установку (стадия: $resume_stage) на диске:" >&2
    lsblk -o NAME,SIZE,MODEL,SERIAL "$resume_disk" >&2
    ask_exact "Продолжить установку на этом диске без разметки? Введите имя диска" "$(basename "$resume_disk")"
}

# Перед установкой ядра и загрузчика /boot обязан быть разделом EFI, иначе ядро уйдёт в подтом @
require_boot_mounted() {
    if [[ "$(findmnt -no FSTYPE "$mount_root/boot" 2>/dev/null)" != vfat ]]; then
        oops "$mount_root/boot не смонтирован как раздел EFI (vfat), продолжать нельзя"
        return 1
    fi
}

ask_system_settings() {
    hostname="$(ask_value "Имя компьютера" "archlinux")"
    user_name="$(ask_value "Имя пользователя (строчные латинские буквы)" "user")"
    if [[ ! "$user_name" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        oops "недопустимое имя пользователя: $user_name"
        return 1
    fi
    timezone="$(ask_value "Часовой пояс" "Asia/Almaty")"
    if [[ ! -f "/usr/share/zoneinfo/$timezone" ]]; then
        oops "нет такого часового пояса: $timezone"
        return 1
    fi
    password="$(ask_secret "Пароль пользователя" 1)"
}

# Доводит установку с той стадии, где она остановилась; разметку и mkfs здесь не вызываю никогда
continue_from_stage() {
    local stage
    local root_dev="$1"
    local root_uuid
    require_boot_mounted || return 1
    stage="$(current_stage)"
    if [[ "$stage" == partitioned ]]; then
        install_base
        stage="$(current_stage)"
    fi
    if [[ "$stage" == base ]]; then
        if [[ -z "${user_name:-}" ]]; then
            ask_system_settings
            confirm_boot_config || { oops "без согласия на запись загрузчика продолжать нельзя"; return 1; }
        fi
        root_uuid="$(blkid -s UUID -o value "$root_dev")"
        configure_system "$hostname" "$user_name" "$timezone" "$root_uuid"
        printf '%s:%s\n' "$user_name" "$password" | arch-chroot "$mount_root" chpasswd
        set_stage "configured:$user_name"
        stage="$(current_stage)"
    fi
    if [[ "$stage" != configured:* ]]; then
        oops "непонятная стадия установки: «$stage» в $mount_root$stage_file"
        return 1
    fi
    local status=0
    run_user_stage "${stage#configured:}" || status=$?
    link_resolv_conf
    umount -R "$mount_root"
    finish_message "$status"
}

finish_message() {
    if (( $1 == 0 )); then
        good "готово: выньте флешку и перезагрузитесь (reboot)"
        return 0
    fi
    oops "система стоит, но установка dotfiles прошла не до конца; после перезагрузки: cd ~/arch-dotfiles && ./install.sh"
    return 1
}

# DNS идёт через systemd-resolved (45-security); внутри arch-chroot ссылку не поставить, делаю это снаружи
link_resolv_conf() {
    # Если шаг 45-security не дошёл до DNS, ссылку не ставлю: иначе после загрузки не будет интернета
    if [[ ! -f "$mount_root/etc/systemd/resolved.conf.d/20-dns-over-tls.conf" ]] || [[ ! -e "$mount_root/etc/systemd/system/dbus-org.freedesktop.resolve1.service" ]]; then
        return 0
    fi
    ln -sf /run/systemd/resolve/stub-resolv.conf "$mount_root/etc/resolv.conf"
}

main() {
    if [[ "$dry_run" == 1 ]]; then
        print_plan
        return 0
    fi
    check_live_iso

    # Сначала ищу недоделанную установку: при согласии продолжаю её, диск не размечаю
    resume_root=""
    resume_efi=""
    resume_disk=""
    resume_stage=""
    if find_unfinished; then
        if confirm_resume; then
            mount_layout "$resume_root" "$resume_efi"
            continue_from_stage "$resume_root"
            return
        fi
        say "продолжать не стал; дальше обычная установка с выбором диска"
    fi

    local disk
    disk="$(choose_disk)"
    ask_system_settings
    if ! confirm_boot_config; then
        oops "без согласия на запись загрузчика ничего не делаю"
        return 1
    fi

    partition_disk "$disk"
    continue_from_stage "$root_part"
}

# Запускаю main только при прямом запуске: тест подключает файл через source и проверяет функции по отдельности
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
