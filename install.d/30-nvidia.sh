#!/usr/bin/env bash
# Sets up the Nvidia driver for Hyprland: nvidia-open-dkms, headers for every kernel, initramfs, DKMS check.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

mkinitcpio_conf="/etc/mkinitcpio.conf"
driver_packages=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils egl-wayland libva-nvidia-driver)
early_modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
initramfs_changed=0
initramfs_marker="$HOME/.local/state/dots/30-nvidia-initramfs-pending"

has_nvidia_gpu() {
    local devices
    if ! devices="$(lspci -nn)"; then
        oops "не смог прочитать PCI-устройства через lspci"
        return 2
    fi
    grep -Ei 'vga|3d|display' <<< "$devices" | grep -i 'nvidia' >/dev/null
}

# dkms собирает модуль под каждое ядро, поэтому заголовки нужны для всех установленных ядер
install_driver() {
    local wanted=("${driver_packages[@]}")
    local missing=()
    local kernel
    local pkg
    for kernel in linux linux-lts linux-zen linux-hardened; do
        if pacman -Qq "$kernel" >/dev/null 2>&1; then
            wanted+=("$kernel-headers")
        fi
    done
    for pkg in "${wanted[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done
    if (( ${#missing[@]} == 0 )); then
        good "пакеты драйвера уже стоят"
        return 0
    fi
    say "ставлю: ${missing[*]}"
    mark_initramfs_pending "$initramfs_marker" || return 1
    if ! run_cmd sudo pacman -Syu --needed --noconfirm "${missing[@]}"; then
        oops "не смог установить драйвер Nvidia и заголовки ядра"
        return 1
    fi
    initramfs_changed=1
}

# Здесь я убираю хук kms: по Arch Wiki он тянет nouveau в initramfs и мешает драйверу Nvidia
drop_kms_hook() {
    if ! grep -Eq '^HOOKS=.*[[:space:](]kms[[:space:])]' "$mkinitcpio_conf"; then
        good "хука kms в mkinitcpio.conf нет"
        return 0
    fi
    if ! ask_yes "Убрать хук kms из $mkinitcpio_conf (рекомендация Arch Wiki для Nvidia)?"; then
        return 0
    fi
    mark_initramfs_pending "$initramfs_marker" || return 1
    if ! run_cmd sudo sed -i -E '/^HOOKS=/ s/([[:space:](])kms([[:space:])])/\1\2/' "$mkinitcpio_conf"; then
        oops "не смог удалить kms из $mkinitcpio_conf"
        return 1
    fi
    initramfs_changed=1
}

# Ранняя загрузка по желанию: по Arch Wiki она ломает гибернацию, поэтому по умолчанию «нет»
add_early_modules() {
    if grep -Eq '^MODULES=.*nvidia_drm' "$mkinitcpio_conf"; then
        good "модули nvidia уже загружаются рано"
        return 0
    fi
    if ! ask_yes "Загружать модули Nvidia рано, в initramfs (быстрее старт, но ломает гибернацию)?"; then
        return 0
    fi
    if ! grep -Eq '^MODULES=\([^)]*\)' "$mkinitcpio_conf"; then
        oops "не нашёл однострочный массив MODULES в $mkinitcpio_conf; добавьте модули вручную"
        return 1
    fi
    mark_initramfs_pending "$initramfs_marker" || return 1
    if ! run_cmd sudo sed -i -E "/^MODULES=/ { s/\)/ $early_modules)/; s/\( /(/ }" "$mkinitcpio_conf"; then
        oops "не смог записать модули Nvidia в $mkinitcpio_conf"
        return 1
    fi
    initramfs_changed=1
}

# Здесь я проверяю образы из пресетов: учитываю и обычный initramfs, и UKI вне /boot.
check_initramfs_age() {
    local preset
    local status
    # /boot после установки с образа смонтирован с dmask=0077: обычный пользователь образов не видит,
    # и без root каждый запуск считал бы их пропавшими и пересобирал
    local as_root=(sudo)
    if [[ "$dry_run" == 1 ]] && ! sudo -n true 2>/dev/null; then
        as_root=()
    fi
    for preset in /etc/mkinitcpio.d/*.preset; do
        [[ -f "$preset" ]] || continue
        status=0
        "${as_root[@]}" bash -c '
            source "$1" || exit 2
            found=0
            for name in "${PRESETS[@]}"; do
                for kind in image uki; do
                    key="${name}_${kind}"
                    output="${!key:-}"
                    [[ -n "$output" ]] || continue
                    found=1
                    [[ -f "$output" ]] || exit 1
                    for conf in /usr/lib/modprobe.d/*nvidia*.conf /etc/modprobe.d/*nvidia*.conf; do
                        [[ -f "$conf" ]] || continue
                        [[ "$conf" -nt "$output" ]] && exit 1
                    done
                done
            done
            (( found == 1 )) || exit 1
            exit 0
        ' bash "$preset" || status=$?
        if (( status == 2 )); then
            oops "не смог прочитать пресет $preset"
            return 1
        elif (( status != 0 )); then
            initramfs_changed=1
        fi
    done
}

# Службы nvidia-suspend/resume/hibernate не включаю: с драйвера 595 сон работает через ядро,
# и по Arch Wiki (NVIDIA/Tips and tricks) эти службы штатно выключены.

# В chroot /sys показывает ядро образа, поэтому проверяю не загруженный модуль, а сборку DKMS
# для каждого установленного ядра; modeset проверяется уже после перезагрузки.
check_dkms_build() {
    local kernel_dir
    local version
    local not_built=0
    local checked=0
    local status
    if [[ "$dry_run" == 1 ]]; then
        return 0
    fi
    for kernel_dir in /usr/lib/modules/*/; do
        version="$(basename "$kernel_dir")"
        if [[ ! -f "$kernel_dir/pkgbase" ]]; then
            continue
        fi
        checked=1
        if status="$(dkms status -k "$version")" && grep -q 'nvidia.*installed' <<< "$status"; then
            good "модуль nvidia собран для ядра $version"
        else
            oops "модуль nvidia не собран для ядра $version: посмотрите dkms status"
            not_built=1
        fi
    done
    if (( checked == 0 )); then
        oops "не нашёл установленного ядра в /usr/lib/modules; сборку Nvidia проверить нельзя"
        return 1
    fi
    say "после перезагрузки проверьте: cat /sys/module/nvidia_drm/parameters/modeset — должно быть Y"
    return "$not_built"
}

main() {
    local gpu_status=0
    has_nvidia_gpu || gpu_status=$?
    if (( gpu_status == 2 )); then
        return 1
    elif (( gpu_status == 1 )); then
        say "видеокарта Nvidia не найдена, пропускаю"
        return 0
    fi
    install_driver
    # Здесь я повторяю незавершённую сборку, даже если конфигурация уже записана прошлым запуском.
    # Повтор идёт после install_driver: тот доставит заголовки нового ядра, без них mkinitcpio упадёт
    if [[ -f "$initramfs_marker" ]]; then
        say "повторяю незавершённую пересборку initramfs после настройки Nvidia"
        rebuild_initramfs "$initramfs_marker" || return 1
    fi

    if [[ ! -r "$mkinitcpio_conf" ]]; then
        oops "не могу прочитать $mkinitcpio_conf"
        return 1
    fi

    drop_kms_hook
    add_early_modules
    check_initramfs_age
    # Здесь я сохраняю метку до проверки DKMS: её ошибка тоже не должна потерять нужную сборку.
    if (( initramfs_changed == 1 )); then
        mark_initramfs_pending "$initramfs_marker" || return 1
    fi
    check_dkms_build
    if (( initramfs_changed == 1 )); then
        if ! rebuild_initramfs "$initramfs_marker"; then
            oops "не смог пересобрать initramfs после настройки Nvidia; не перезагружайтесь до sudo mkinitcpio -P"
            return 1
        fi
    fi
}

main
