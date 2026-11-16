#!/usr/bin/env bash
# Checks failure paths with fake commands: backup rollback after a failed mv, config restore after a failed stow
# (first and repeated install), and that a failed matugen run leaves the old colors untouched.
# This work made by Anfinogentov Nikita

# Проверки нарочно в одинарных кавычках: их раскрывает eval в check, а не shell при вызове
# shellcheck disable=SC2016

set -uo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
failures=0

check() {
    local label="$1"
    local condition="$2"
    if eval "$condition"; then
        printf 'PASS %s\n' "$label"
    else
        printf 'FAIL %s\n' "$label"
        failures=$((failures + 1))
    fi
}

# Здесь я делаю поддельные stow, mv и matugen: их поведение задают переменные FAKE_*
make_fakes() {
    mkdir -p "$work_dir/bin"
    cat > "$work_dir/bin/stow" <<'FAKE'
#!/usr/bin/env bash
[[ "${FAKE_STOW_FAILS:-0}" == 1 ]] && exit 1
exit 0
FAKE
    cat > "$work_dir/bin/mv" <<'FAKE'
#!/usr/bin/env bash
if [[ -n "${FAKE_MV_FAILS_ON:-}" && "$*" == *"$FAKE_MV_FAILS_ON"* ]]; then
    exit 1
fi
exec /usr/bin/mv "$@"
FAKE
    # matugen: с FAKE_MATUGEN_OK=1 пишет «new» во все output_path под --prefix, иначе падает
    cat > "$work_dir/bin/matugen" <<'FAKE'
#!/usr/bin/env bash
[[ "${FAKE_MATUGEN_OK:-0}" == 1 ]] || exit 1
prefix="${@: -1}"
while IFS= read -r rel; do
    mkdir -p "$(dirname "$prefix$HOME/$rel")"
    printf 'new\n' > "$prefix$HOME/$rel"
done < <(sed -n 's/^output_path = "~\/\(.*\)"$/\1/p' "$HOME/.config/matugen/config.toml")
exit 0
FAKE
    chmod +x "$work_dir/bin/"*
}

new_home() {
    local home="$work_dir/$1"
    mkdir -p "$home/.config/kitty" "$home/.config/rofi"
    printf 'font_size 99\n' > "$home/.config/kitty/kitty.conf"
    printf '/* old rofi */\n' > "$home/.config/rofi/config.rasi"
    printf '%s\n' "$home"
}

backup_rollback() {
    local home
    home="$(new_home backup_home)"
    env HOME="$home" PATH="$work_dir/bin:$PATH" FAKE_MV_FAILS_ON=".config/rofi" \
        bash "$repo_dir/install.d/50-backup.sh" > "$work_dir/out-backup" 2>&1
    printf 'RC=%s\n' "$?" >> "$work_dir/out-backup"
    check "backup: failed mv gives non-zero code" '! grep -q "^RC=0" "$work_dir/out-backup"'
    check "backup: Ooops message" 'grep -q "Ooops.." "$work_dir/out-backup"'
    check "backup: already moved kitty.conf is back" '[[ "$(cat "$work_dir/backup_home/.config/kitty/kitty.conf")" == "font_size 99" ]]'
    check "backup: rofi config untouched" '[[ -f "$work_dir/backup_home/.config/rofi/config.rasi" ]]'
    check "backup: no journal left" '[[ ! -f "$work_dir/backup_home/.local/state/dots/last-backup" ]]'
}

stow_restore() {
    local label="$1"
    local first_install="$2"
    local home
    home="$(new_home "stow_$label")"
    env HOME="$home" PATH="$work_dir/bin:$PATH" bash "$repo_dir/install.d/50-backup.sh" > /dev/null 2>&1
    if [[ "$first_install" == 0 ]]; then
        touch "$home/.local/state/dots/linked"
    fi
    env HOME="$home" PATH="$work_dir/bin:$PATH" FAKE_STOW_FAILS=1 \
        bash "$repo_dir/install.d/55-stow.sh" > "$work_dir/out-stow-$label" 2>&1
    printf 'RC=%s\n' "$?" >> "$work_dir/out-stow-$label"
    check "stow fails ($label): non-zero code" "! grep -q '^RC=0' '$work_dir/out-stow-$label'"
    check "stow fails ($label): old kitty.conf restored" "[[ \"\$(cat '$home/.config/kitty/kitty.conf')\" == 'font_size 99' ]]"
}

palette_untouched() {
    local home="$work_dir/palette_home"
    mkdir -p "$home/.config/matugen" "$home/.config/kitty" "$home/Pictures/wallpapers"
    cp "$repo_dir/matugen/.config/matugen/config.toml" "$home/.config/matugen/config.toml"
    printf 'color0 #123456\n' > "$home/.config/kitty/colors.conf"
    cp "$repo_dir/wallpapers/01-deep-blue.jpg" "$home/Pictures/wallpapers/"
    env HOME="$home" PATH="$work_dir/bin:$PATH" WAYLAND_DISPLAY= \
        bash "$repo_dir/scripts/.local/bin/wallpaper-set" "$home/Pictures/wallpapers/01-deep-blue.jpg" > "$work_dir/out-palette" 2>&1
    check "failed matugen: old kitty colors kept" '[[ "$(cat "$work_dir/palette_home/.config/kitty/colors.conf")" == "color0 #123456" ]]'
    check "failed matugen: reported with Ooops" 'grep -q "Ooops.." "$work_dir/out-palette"'
    : > "$home/.config/kitty/colors.conf"
    check "empty colors file is not a complete palette" '! env HOME="$work_dir/palette_home" bash "$repo_dir/scripts/.local/bin/wallpaper-set" --check'

    # Замена набора рвётся на rofi: весь набор, в том числе уже заменённый kitty, должен вернуться к старому
    printf 'color0 #123456\n' > "$home/.config/kitty/colors.conf"
    mkdir -p "$home/.config/rofi"
    printf '/* old rofi colors */\n' > "$home/.config/rofi/colors.rasi"
    env HOME="$home" PATH="$work_dir/bin:$PATH" WAYLAND_DISPLAY= FAKE_MATUGEN_OK=1 FAKE_MV_FAILS_ON="rofi/colors.rasi.dots-new" \
        bash "$repo_dir/scripts/.local/bin/wallpaper-set" "$home/Pictures/wallpapers/01-deep-blue.jpg" > "$work_dir/out-swap" 2>&1
    check "swap fails midway: kitty colors rolled back" '[[ "$(cat "$work_dir/palette_home/.config/kitty/colors.conf")" == "color0 #123456" ]]'
    check "swap fails midway: rofi colors untouched" '[[ "$(cat "$work_dir/palette_home/.config/rofi/colors.rasi")" == "/* old rofi colors */" ]]'
    check "swap fails midway: palette not marked complete" '! env HOME="$work_dir/palette_home" bash "$repo_dir/scripts/.local/bin/wallpaper-set" --check'
    check "swap fails midway: no leftovers" '! find "$work_dir/palette_home" -name "*.dots-new" -o -name "*.dots-old" | grep -q .'

    # Без сбоев: весь набор новый, метка готовности стоит
    env HOME="$home" PATH="$work_dir/bin:$PATH" WAYLAND_DISPLAY= FAKE_MATUGEN_OK=1 \
        bash "$repo_dir/scripts/.local/bin/wallpaper-set" "$home/Pictures/wallpapers/01-deep-blue.jpg" > "$work_dir/out-swap-ok" 2>&1
    check "swap ok: new colors and complete mark" '[[ "$(cat "$work_dir/palette_home/.config/kitty/colors.conf")" == new ]] && env HOME="$work_dir/palette_home" bash "$repo_dir/scripts/.local/bin/wallpaper-set" --check'
}

chroot_flag() {
    check "chroot flag from 05-from-iso is honoured" 'DOTS_CHROOT=1 bash -c "source \"$repo_dir/lib/ui.sh\"; in_chroot"'
}

main() {
    make_fakes
    backup_rollback
    stow_restore first 1
    stow_restore repeat 0
    palette_untouched
    chroot_flag
    if (( failures > 0 )); then
        printf '%d rollback checks failed\n' "$failures"
        cat "$work_dir"/out-*
        exit 1
    fi
    printf 'all rollback checks passed\n'
}

main
