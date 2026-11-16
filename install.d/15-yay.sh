#!/usr/bin/env bash
# Installs the yay AUR helper (yay-bin package) if it is missing, after showing its PKGBUILD;
# then saves yay settings that always show PKGBUILD diffs before a build.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

yay_config="${XDG_CONFIG_HOME:-$HOME/.config}/yay/config.json"

install_yay() {
    local tool
    for tool in git makepkg; do
        if ! command -v "$tool" >/dev/null 2>&1 && [[ "$dry_run" == 0 ]]; then
            oops "нет $tool: сначала нужен шаг 10-base"
            return 1
        fi
    done

    if [[ "$dry_run" == 1 ]]; then
        run_cmd git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        review_pkgbuild /tmp/yay-bin yay-bin
        run_cmd makepkg -si --noconfirm
        return 0
    fi

    # build_dir глобальная: ловушка EXIT срабатывает уже после выхода из функции
    build_dir="$(mktemp -d)"
    trap 'rm -rf "$build_dir"' EXIT
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build_dir/yay-bin"
    if ! review_pkgbuild "$build_dir/yay-bin" yay-bin; then
        oops "сборка yay-bin отменена"
        return 1
    fi
    (cd "$build_dir/yay-bin" && makepkg -si --noconfirm)
    good "yay установлен"
}

# Здесь я сохраняю в настройки yay показ диффов PKGBUILD: при обновлениях из AUR видно, что поменялось
save_yay_settings() {
    if [[ -f "$yay_config" ]] && grep -q '"diffmenu": true' "$yay_config" && grep -q '"answerdiff": "All"' "$yay_config"; then
        good "yay показывает диффы PKGBUILD перед сборкой"
        return 0
    fi
    if ! command -v yay >/dev/null 2>&1 && [[ "$dry_run" == 0 ]]; then
        return 1
    fi
    run_cmd yay --save --diffmenu --answerdiff All
}

main() {
    if command -v yay >/dev/null 2>&1; then
        good "yay уже стоит"
    else
        install_yay
    fi
    save_yay_settings
}

main
