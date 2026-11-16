#!/usr/bin/env bash
# Optional (--bootloader): adds nvidia_drm.modeset=1 to the kernel command line after a typed "да".
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"
# shellcheck source=../lib/bootloader.sh
source "$repo_dir/lib/bootloader.sh"

main() {
    if [[ "$want_bootloader" != 1 ]]; then
        say "пропускаю: nvidia-utils сам включает modeset, параметры ядра не нужны (добавить всё равно: --bootloader)"
        return 0
    fi
    if [[ "$dry_run" == 1 ]]; then
        say "[dry-run] нашёл бы загрузчик, показал бы diff с nvidia_drm.modeset=1 и попросил ввести «да»"
        return 0
    fi
    add_kernel_param "nvidia_drm.modeset=1"
}

main
