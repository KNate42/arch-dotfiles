#!/usr/bin/env bash
# Installs the dotfiles on Arch Linux: runs every step from install.d one by one.
# Usage: ./install.sh [--dry-run] [--bootloader] [--apparmor-d] [--secure-boot] [--trust-aur] [--from-iso] [--only NAME[,NAME]] [--help]
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# shellcheck source=lib/ui.sh
source "$repo_dir/lib/ui.sh"

print_help() {
    cat <<'HELP'
Установка dotfiles на Arch Linux.

  ./install.sh                 обычная установка на уже установленный Arch
  ./install.sh --dry-run       показать, что будет сделано, ничего не меняя
  ./install.sh --bootloader    дополнительно предложить правку параметров ядра
  ./install.sh --apparmor-d    дополнительно набор профилей apparmor.d из AUR (спросит «да»)
  ./install.sh --secure-boot   свои ключи Secure Boot через sbctl (спросит подтверждение)
  ./install.sh --trust-aur     не показывать PKGBUILD из AUR перед сборкой (быстрее, но без проверки)
  ./install.sh --from-iso      с установочного образа: разметка диска, pacstrap, потом всё остальное
  ./install.sh --only 30,55    запустить только шаги с этими номерами или именами

Каждый шаг можно запустить и отдельно: bash install.d/30-nvidia.sh --dry-run
HELP
}

# В текстовой консоли (tty) шрифт по умолчанию без кириллицы, и русские сообщения превращаются в квадраты.
# Здесь я ставлю шрифт cyr-sun16 из пакета kbd (Arch Wiki: Linux console#Fonts) — только для этой консоли.
console_font() {
    local tty_name
    tty_name="$(tty 2>/dev/null || true)"
    if [[ "$tty_name" == /dev/tty[0-9]* ]] && command -v setfont >/dev/null 2>&1; then
        setfont cyr-sun16 2>/dev/null || true
    fi
}

main() {
    local module_flags=()
    local only=""
    local from_iso=0
    console_font
    local arg

    while (( $# > 0 )); do
        arg="$1"
        case "$arg" in
            --dry-run|--bootloader|--apparmor-d|--secure-boot|--trust-aur) module_flags+=("$arg") ;;
            --from-iso) from_iso=1 ;;
            --only)
                shift
                only="${1:-}"
                ;;
            -h|--help)
                print_help
                return 0
                ;;
            *)
                oops "неизвестный флаг: $arg (см. --help)"
                return 1
                ;;
        esac
        shift
    done

    # Здесь я отдаю установку с образа отдельному модулю: он сам потом вызовет остальные шаги
    if (( from_iso == 1 )); then
        bash "$repo_dir/install.d/05-from-iso.sh" "${module_flags[@]}"
        return $?
    fi

    local failed=()
    local module
    local name
    local broken_dep
    for module in "$repo_dir"/install.d/[0-9]*.sh; do
        name="$(basename "$module" .sh)"
        if [[ "$name" == 05-from-iso ]]; then
            continue
        fi
        if [[ -n "$only" ]] && ! module_selected "$name" "$only"; then
            continue
        fi
        # Шаг, у которого упала зависимость, не запускаю: иначе, например, SDDM включится поверх сломанного драйвера
        if broken_dep="$(failed_dependency "$name" "${failed[@]}")"; then
            warn "шаг $name пропущен: не прошёл нужный ему шаг $broken_dep"
            failed+=("$name")
            continue
        fi
        say "шаг $name"
        if bash "$module" "${module_flags[@]}"; then
            good "$name"
        elif [[ "$name" == 00-preflight ]]; then
            oops "проверки окружения не прошли, дальше идти нельзя"
            return 1
        else
            oops "шаг $name упал; зависящие от него шаги будут пропущены"
            failed+=("$name")
        fi
    done

    printf '\n'
    if (( ${#failed[@]} > 0 )); then
        oops "не получились или пропущены шаги: ${failed[*]}"
        oops "исправьте причину и запустите ./install.sh ещё раз — готовые шаги повторно ничего не сломают"
        return 1
    fi
    if [[ " ${module_flags[*]} " == *" --dry-run "* ]]; then
        good "это был --dry-run: ничего не изменено"
        return 0
    fi
    good "всё готово. Перезагрузитесь и выберите сессию Hyprland в SDDM"
}

# Зависимости шагов: шаг запускается, только если все перечисленные прошли (или не запускались из-за --only)
step_dependencies() {
    case "$1" in
        15-yay|30-nvidia|38-apparmor|40-dev|45-security|50-backup) printf '10-base\n' ;;
        20-aur) printf '15-yay\n' ;;
        35-bootloader|36-secureboot) printf '30-nvidia\n' ;;
        55-stow) printf '50-backup\n' ;;
        60-theme) printf '55-stow\n' ;;
        70-sddm) printf '60-theme\n' ;;
        80-services) printf '%s\n' 30-nvidia 38-apparmor 45-security 60-theme 70-sddm ;;
        *) ;;
    esac
}

# Печатает первую упавшую зависимость шага; код 0, если такая есть
failed_dependency() {
    local name="$1"
    shift
    local dep
    local done_step
    while read -r dep; do
        for done_step in "$@"; do
            if [[ "$dep" == "$done_step" ]]; then
                printf '%s\n' "$dep"
                return 0
            fi
        done
    done < <(step_dependencies "$name")
    return 1
}

# Шаг выбран, если его номер или имя есть в списке --only через запятую
module_selected() {
    local name="$1"
    local list="$2"
    local item
    local IFS=','
    for item in $list; do
        if [[ "$name" == "$item" || "$name" == "$item"-* || "$name" == *-"$item" ]]; then
            return 0
        fi
    done
    return 1
}

main "$@"
