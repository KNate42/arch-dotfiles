#!/usr/bin/env bash
# First theming pass: user folders, wallpapers, qt5ct/qt6ct settings, first matugen palette.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

copy_wallpapers() {
    # Путь один и тот же везде (здесь, в wallpaper-set и в окне выбора), не зависит от языка XDG-папок
    local target_dir="$HOME/Pictures/wallpapers"
    local image
    run_cmd mkdir -p "$target_dir"
    for image in "$repo_dir"/wallpapers/*; do
        # Свои обои из репозитория обновляю при изменении: имена 01-… заняты набором, чужие файлы не трогаю
        if [[ -f "$image" ]] && ! cmp -s "$image" "$target_dir/$(basename "$image")"; then
            run_cmd cp "$image" "$target_dir/"
        fi
    done
    good "обои в $target_dir"
}

# Пишу файл пользователя, только если содержимое отличается, чтобы повторный запуск ничего не трогал
write_user_file() {
    local target="$1"
    local content="$2"
    if [[ -f "$target" && "$(cat "$target")" == "$content" ]]; then
        good "$target уже в порядке"
        return 0
    fi
    if [[ "$dry_run" == 1 ]]; then
        printf '\033[2m[dry-run]\033[0m записал бы %s\n' "$target"
        return 0
    fi
    mkdir -p "$(dirname "$target")"
    # Ссылку сначала убираю, чтобы не записать через неё в чужой файл (старый лежит в бэкапе)
    if [[ -L "$target" ]]; then
        rm -f "$target"
    fi
    printf '%s\n' "$content" > "$target"
    good "записал $target"
}

# qtct = qt5ct и qt6ct; путь к палитре в их конфиге должен быть полным, поэтому собираю его здесь
qtct_config() {
    local tool="$1"
    local font='"JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"'
    printf '%s\n' \
        "[Appearance]" \
        "color_scheme_path=$HOME/.config/$tool/colors/matugen.conf" \
        "custom_palette=true" \
        "icon_theme=Papirus-Dark" \
        "standard_dialogs=default" \
        "style=Fusion" \
        "" \
        "[Fonts]" \
        "fixed=$font" \
        "general=$font"
}

first_palette() {
    if bash "$repo_dir/scripts/.local/bin/wallpaper-set" --check 2>/dev/null; then
        good "все файлы палитры matugen на месте"
        return 0
    fi
    if ! command -v matugen >/dev/null 2>&1 && [[ "$dry_run" == 0 ]]; then
        oops "нет matugen: сначала нужен шаг 10-base"
        return 1
    fi
    run_cmd bash "$repo_dir/scripts/.local/bin/wallpaper-set" --restore
}

main() {
    if command -v xdg-user-dirs-update >/dev/null 2>&1; then
        run_cmd xdg-user-dirs-update
    fi
    copy_wallpapers
    write_user_file "$HOME/.config/qt6ct/qt6ct.conf" "$(qtct_config qt6ct)"
    write_user_file "$HOME/.config/qt5ct/qt5ct.conf" "$(qtct_config qt5ct)"
    first_palette
}

main
