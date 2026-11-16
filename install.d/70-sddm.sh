#!/usr/bin/env bash
# Installs the "dots" SDDM theme and the shared folder where matugen leaves its colors and wallpaper.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

theme_src="$repo_dir/sddm-theme"
theme_dest="/usr/share/sddm/themes/dots"
shared_dir="/var/lib/dots-sddm"
cache_dir="$HOME/.cache"

install_theme() {
    if [[ ! -f "$theme_src/Main.qml" ]]; then
        oops "нет темы SDDM в $theme_src"
        return 1
    fi
    # rsync сам ничего не копирует, если тема не менялась; theme.conf.user — ссылка, её не трогаю
    # Время папок не переношу (иначе каждый повтор менял бы их), права задаю явно: тема читается пользователем sddm
    run_cmd sudo rsync -a --omit-dir-times --chmod=D755,F644 --delete --exclude theme.conf.user "$theme_src/" "$theme_dest/"
    good "файлы темы в $theme_dest"
}

# Здесь я делаю папку, куда пользователь пишет без sudo, а SDDM только читает
prepare_shared_dir() {
    local owner
    owner="$(stat -c %U "$shared_dir" 2>/dev/null || true)"
    if [[ "$owner" != "$USER" ]]; then
        run_cmd sudo install -d -m 755 -o "$USER" -g "$(id -gn)" "$shared_dir"
    fi
    if [[ "$(readlink "$theme_dest/theme.conf.user" 2>/dev/null)" != "$shared_dir/theme.conf.user" ]]; then
        run_cmd sudo ln -sfn "$shared_dir/theme.conf.user" "$theme_dest/theme.conf.user"
    fi
    good "общая папка $shared_dir готова"
}

copy_current_look() {
    local wallpaper=""
    if [[ -f "$cache_dir/matugen/sddm-theme.conf" ]] && ! cmp -s "$cache_dir/matugen/sddm-theme.conf" "$shared_dir/theme.conf.user"; then
        run_cmd cp -f "$cache_dir/matugen/sddm-theme.conf" "$shared_dir/theme.conf.user"
    fi
    if [[ -f "$cache_dir/dots/wallpaper" ]]; then
        wallpaper="$(cat "$cache_dir/dots/wallpaper")"
    fi
    if [[ -n "$wallpaper" && -f "$wallpaper" ]] && ! cmp -s "$wallpaper" "$shared_dir/background"; then
        run_cmd cp -f "$wallpaper" "$shared_dir/background"
    fi
}

main() {
    if [[ ! -d /usr/share/sddm ]] && [[ "$dry_run" == 0 ]]; then
        oops "sddm не установлен: сначала нужен шаг 10-base"
        return 1
    fi
    install_theme
    prepare_shared_dir
    copy_current_look
    write_file_root /etc/sddm.conf.d/10-dots.conf "$(printf '%s\n' '[Theme]' 'Current=dots' 'CursorTheme=Bibata-Modern-Classic' 'CursorSize=24')"
    good "SDDM использует тему dots"
}

main
