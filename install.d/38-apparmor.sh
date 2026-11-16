#!/usr/bin/env bash
# AppArmor: package, apparmor.service and the lsm= kernel parameter (loader change only after a typed "да").
# Optional (--apparmor-d): the apparmor.d profile set from AUR, with desktop programs kept in complain mode.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"
# shellcheck source=../lib/bootloader.sh
source "$repo_dir/lib/bootloader.sh"

# lsm = порядок модулей безопасности ядра; строка из Arch Wiki (AppArmor#Installation), сверено 16.11.2026
apparmor_param="lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
# Программы рабочего стола: их профили из apparmor.d держу в режиме complain (только журнал, без запретов)
desktop_programs=(Hyprland hyprland hyprctl hyprlock hypridle quickshell qs kitty rofi awww awww-daemon matugen sddm sddm-greeter-qt6 wl-paste cliphist)

install_apparmor() {
    if pacman -Qq apparmor >/dev/null 2>&1; then
        good "apparmor уже стоит"
    else
        run_cmd sudo pacman -S --needed --noconfirm apparmor
    fi
    if systemctl is-enabled -q apparmor.service 2>/dev/null; then
        good "apparmor.service уже включена"
    else
        run_cmd sudo systemctl enable apparmor.service
    fi
}

# Если AppArmor уже работает в ядре, загрузчик не трогаю
enable_in_kernel() {
    if grep -q apparmor /sys/kernel/security/lsm 2>/dev/null && ! in_chroot; then
        good "AppArmor уже включён в ядре"
        return 0
    fi
    if [[ "$dry_run" == 1 ]]; then
        say "[dry-run] показал бы diff загрузчика с $apparmor_param и попросил ввести «да»"
        return 0
    fi
    # У контейнера нет своего загрузчика и ядра
    if systemd-detect-virt --container >/dev/null 2>&1; then
        warn "это контейнер: параметр ядра не трогаю"
        return 0
    fi
    add_kernel_param "$apparmor_param" || return 1
    say "после перезагрузки проверьте: aa-enabled (должно быть Yes) и sudo aa-status"
    say "если правку загрузчика вы не приняли, AppArmor не заработает; запустить шаг снова: bash install.d/38-apparmor.sh"
}

# apparmor.d — около 1500 профилей; по Arch Wiki проект пока не считается стабильным
install_apparmor_d() {
    local review_dir
    local name
    warn "apparmor.d: большой набор профилей из AUR. Риск: какие-то программы перестанут работать, пока их профиль не поправят."
    warn "Профили Hyprland, kitty, Quickshell и других программ рабочего стола я переведу в режим complain (без запретов)."
    if [[ "$dry_run" == 1 ]]; then
        say "[dry-run] показал бы PKGBUILD apparmor.d, спросил «да», поставил бы его и перевёл профили рабочего стола в complain"
        return 0
    fi
    if pacman -Qq apparmor.d >/dev/null 2>&1; then
        good "apparmor.d уже стоит"
    else
        if ! command -v yay >/dev/null 2>&1; then
            oops "нет yay: сначала нужен шаг 15-yay"
            return 1
        fi
        if ! ask_exact "Поставить набор профилей apparmor.d из AUR?" "да"; then
            say "apparmor.d не ставлю"
            return 0
        fi
        review_dir="$(mktemp -d)"
        (cd "$review_dir" && yay -G apparmor.d >/dev/null)
        if ! review_pkgbuild "$review_dir/apparmor.d" apparmor.d; then
            rm -rf "$review_dir"
            say "apparmor.d не ставлю"
            return 0
        fi
        rm -rf "$review_dir"
        yay -S --needed --noconfirm --answerdiff None --answerclean None apparmor.d
    fi
    for name in "${desktop_programs[@]}"; do
        if [[ -f "/etc/apparmor.d/$name" ]]; then
            sudo aa-complain "/etc/apparmor.d/$name" >/dev/null && good "профиль $name — complain"
        fi
    done
}

main() {
    install_apparmor
    enable_in_kernel
    if [[ "$want_apparmor_d" == 1 ]]; then
        install_apparmor_d
    fi
}

main
