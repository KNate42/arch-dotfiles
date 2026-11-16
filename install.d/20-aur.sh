#!/usr/bin/env bash
# Installs packages from packages/aur.txt through yay, showing every PKGBUILD first (skip with --trust-aur).
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

list_file="$repo_dir/packages/aur.txt"

main() {
    local wanted=()
    local missing=()
    local approved=()
    local pkg
    mapfile -t wanted < <(read_list "$list_file")

    for pkg in "${wanted[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        good "все пакеты из AUR уже стоят"
        return 0
    fi

    if ! command -v yay >/dev/null 2>&1 && [[ "$dry_run" == 0 ]]; then
        oops "нет yay: сначала нужен шаг 15-yay"
        return 1
    fi

    # review_dir глобальная: ловушка EXIT срабатывает уже после выхода из main
    review_dir="/tmp/aur-review"
    if [[ "$dry_run" == 0 ]]; then
        review_dir="$(mktemp -d)"
        trap 'rm -rf "$review_dir"' EXIT
    fi
    for pkg in "${missing[@]}"; do
        if [[ "$dry_run" == 0 && "$trust_aur" == 0 ]]; then
            (cd "$review_dir" && yay -G "$pkg" >/dev/null)
        fi
        if review_pkgbuild "$review_dir/$pkg" "$pkg"; then
            approved+=("$pkg")
        else
            warn "пропускаю $pkg"
        fi
    done

    if (( ${#approved[@]} == 0 )); then
        oops "ни один пакет из AUR не одобрен"
        return 1
    fi
    say "ставлю из AUR: ${approved[*]}"
    # PKGBUILD уже показан выше, поэтому второй раз yay его не показывает
    run_cmd yay -S --needed --noconfirm --answerdiff None --answerclean None "${approved[@]}"
    if (( ${#approved[@]} < ${#missing[@]} )); then
        return 1
    fi
}

main
