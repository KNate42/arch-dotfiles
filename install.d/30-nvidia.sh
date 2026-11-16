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

has_nvidia_gpu() {
    lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | grep -qi 'nvidia'
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
    run_cmd sudo pacman -S --needed --noconfirm "${missing[@]}"
}

# Здесь я убираю хук kms: по Arch Wiki он тянет nouveau в initramfs и мешает драйверу Nvidia
drop_kms_hook() {
    if ! grep -Eq '^HOOKS=.*[( ]kms[ )]' "$mkinitcpio_conf"; then
        good "хука kms в mkinitcpio.conf нет"
        return 1
    fi
    if ! ask_yes "Убрать хук kms из $mkinitcpio_conf (рекомендация Arch Wiki для Nvidia)?"; then
        return 1
    fi
    run_cmd sudo sed -i -E '/^HOOKS=/ s/ kms([ )])/\1/' "$mkinitcpio_conf"
}

# Ранняя загрузка по желанию: по Arch Wiki она ломает гибернацию, поэтому по умолчанию «нет»
add_early_modules() {
    if grep -Eq '^MODULES=.*nvidia_drm' "$mkinitcpio_conf"; then
        good "модули nvidia уже загружаются рано"
        return 1
    fi
    if ! ask_yes "Загружать модули Nvidia рано, в initramfs (быстрее старт, но ломает гибернацию)?"; then
        return 1
    fi
    run_cmd sudo sed -i -E "/^MODULES=/ { s/\)/ $early_modules)/; s/\( /(/ }" "$mkinitcpio_conf"
}

# Службы nvidia-suspend/resume/hibernate не включаю: с драйвера 595 сон работает через ядро,
# и по Arch Wiki (NVIDIA/Tips and tricks) эти службы штатно выключены.

# В chroot /sys показывает ядро образа, поэтому проверяю не загруженный модуль, а сборку DKMS
# для каждого установленного ядра; modeset проверяется уже после перезагрузки.
check_dkms_build() {
    local kernel_dir
    local version
    local not_built=0
    if [[ "$dry_run" == 1 ]]; then
        return 0
    fi
    for kernel_dir in /usr/lib/modules/*/; do
        version="$(basename "$kernel_dir")"
        if [[ ! -f "$kernel_dir/pkgbase" ]]; then
            continue
        fi
        if dkms status -k "$version" 2>/dev/null | grep -q 'nvidia.*installed'; then
            good "модуль nvidia собран для ядра $version"
        else
            oops "модуль nvidia не собран для ядра $version: посмотрите dkms status"
            not_built=1
        fi
    done
    say "после перезагрузки проверьте: cat /sys/module/nvidia_drm/parameters/modeset — должно быть Y"
    return "$not_built"
}

main() {
    if ! has_nvidia_gpu; then
        say "видеокарта Nvidia не найдена, пропускаю"
        return 0
    fi
    install_driver

    local initramfs_changed=0
    if drop_kms_hook; then
        initramfs_changed=1
    fi
    if add_early_modules; then
        initramfs_changed=1
    fi
    if (( initramfs_changed == 1 )); then
        run_cmd sudo mkinitcpio -P
    fi

    check_dkms_build
}

main
