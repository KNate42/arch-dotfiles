#!/usr/bin/env bash
# Installs every package from packages/pacman.txt that is not installed yet.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

list_file="$repo_dir/packages/pacman.txt"
initramfs_marker="$HOME/.local/state/dots/10-base-initramfs-pending"

main() {
    # Здесь я повторяю незавершённую сборку до возможного выхода «все пакеты уже стоят».
    if [[ -f "$initramfs_marker" ]]; then
        say "повторяю незавершённую пересборку initramfs после установки пакетов"
        rebuild_initramfs "$initramfs_marker" || return 1
    fi
    local wanted=()
    local missing=()
    local pkg
    mapfile -t wanted < <(read_list "$list_file")

    # Здесь я ставлю заголовки вместе с DKMS, до запуска пакетных хуков сборки драйвера.
    local kernel
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
        good "все ${#wanted[@]} пакетов уже стоят"
        return 0
    fi

    say "ставлю пакеты (${#missing[@]}): ${missing[*]}"
    # Здесь я обновляю систему вместе с установкой: частичные обновления Arch не поддерживает.
    # Зеркало иногда обрывает загрузку, поэтому пробую до трёх раз; скачанное pacman не качает заново
    local attempt
    for attempt in 1 2 3; do
        if run_cmd sudo pacman -Syu --needed --noconfirm "${missing[@]}"; then
            # Здесь я пересобираю образ и после обновления уже установленного драйвера через -Syu.
            if [[ "$dry_run" == 1 ]] || pacman -Qq nvidia-utils >/dev/null 2>&1; then
                if ! rebuild_initramfs "$initramfs_marker"; then
                    oops "пакеты установлены, но initramfs не пересобран; выполните sudo mkinitcpio -P перед перезагрузкой"
                    return 1
                fi
            fi
            return 0
        fi
        warn "pacman не справился (попытка $attempt из 3)"
    done
    oops "не получилось поставить пакеты, проверьте интернет и зеркала в /etc/pacman.d/mirrorlist"
    return 1
}

main
