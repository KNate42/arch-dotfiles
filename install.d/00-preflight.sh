#!/usr/bin/env bash
# Checks that we run on Arch as a normal user with sudo and internet; enables multilib for 32-bit Nvidia libs.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        oops "это не Arch Linux (нет /etc/arch-release)"
        return 1
    fi
    good "это Arch Linux"
}

check_user() {
    if [[ "$EUID" -eq 0 ]]; then
        oops "запускайте от обычного пользователя, не от root: sudo я попрошу сам"
        return 1
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        oops "не установлен sudo"
        return 1
    fi
    good "пользователь $USER, домашняя папка $HOME"
}

check_network() {
    if ! curl -sfI --max-time 10 https://archlinux.org >/dev/null; then
        oops "нет интернета: archlinux.org не отвечает"
        return 1
    fi
    good "интернет есть"
}

# Здесь я включаю multilib: без него не поставится lib32-nvidia-utils для Steam и Wine
enable_multilib() {
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        good "multilib уже включён"
        return 0
    fi
    say "включаю multilib в /etc/pacman.conf"
    if grep -q '^#\[multilib\]' /etc/pacman.conf; then
        run_cmd sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    else
        # В урезанных образах (например, docker) секции нет совсем — дописываю её
        run_cmd sudo sh -c 'printf "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" >> /etc/pacman.conf'
    fi
}

# Здесь я убираю временный «sudo без пароля», если установка с образа оборвалась (например, пропало питание)
# и не успела удалить его сама. Внутри самой установки с образа (DOTS_CHROOT=1) он ещё нужен.
remove_leftover_nopasswd() {
    local leftover="/etc/sudoers.d/99-dots-install"
    if [[ "${DOTS_CHROOT:-0}" == 1 || "$dry_run" == 1 ]]; then
        return 0
    fi
    if sudo test -e "$leftover"; then
        warn "нашёл забытый $leftover (sudo без пароля) — удаляю"
        sudo rm -f "$leftover"
    fi
}

main() {
    check_arch
    check_user
    check_network
    if [[ "$dry_run" == 0 ]]; then
        # Здесь я сначала пробую без пароля: при установке с образа действует временный NOPASSWD,
        # а sudo -v всё равно требует пароль, если у пользователя есть и обычное правило wheel
        sudo -n true 2>/dev/null || sudo -v
    fi
    remove_leftover_nopasswd
    enable_multilib
}

main
