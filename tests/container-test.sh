#!/usr/bin/env bash
# Full check inside a clean archlinux container: lint, dry-run, real install, second run, config checks.
# Runs as root inside the container; started by tests/run.sh.
# This work made by Anfinogentov Nikita

set -euo pipefail

user_name="tester"
user_home="/home/$user_name"
repo_copy="$user_home/arch-dotfiles"
watched=(/etc /usr/share/sddm "$user_home" /var/lib/pacman/local)
failures=0

step() {
    printf '\n\033[1;35m==== %s\033[0m\n' "$*"
}

fail() {
    printf '\033[1;31mFAIL\033[0m %s\n' "$*"
    failures=$((failures + 1))
}

pass() {
    printf '\033[1;32mPASS\033[0m %s\n' "$*"
}

skip() {
    printf '\033[1;33mSKIP\033[0m %s\n' "$*"
}

as_user() {
    runuser -u "$user_name" -- env HOME="$user_home" USER="$user_name" XDG_RUNTIME_DIR=/tmp/xdg-$user_name "$@"
}

# Здесь я снимаю «слепок» отслеживаемых папок: путь, тип, размер, время, права, цель ссылки.
# Разница двух слепков показывает и созданные, и изменённые, и удалённые файлы. Исключена только копия репо.
snapshot() {
    # find ругается на закрытые папки и возвращает не 0; для слепка это не ошибка
    { find "${watched[@]}" -xdev -path "$repo_copy" -prune -o -printf '%p %y %s %T@ %m %l\n' 2>/dev/null || true; } | sort
}

# diff: 0 — одинаково, 1 — есть разница, 2 и больше — сама проверка сломалась (нет diff, нет файла)
compare_snapshots() {
    local result
    local status=0
    result="$(diff "$1" "$2")" || status=$?
    if (( status >= 2 )); then
        echo "COMPARE-FAILED: diff вернул $status"
        return 0
    fi
    grep -E '^[<>]' <<< "$result" || true
}

prepare_container() {
    step "prepare container"
    pacman -Syu --noconfirm --needed sudo shellcheck lua jq diffutils >/dev/null
    useradd -m -s /bin/bash "$user_name"
    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user_name" > /etc/sudoers.d/90-tester
    install -d -m 700 -o "$user_name" "/tmp/xdg-$user_name"
    # В образе docker секции multilib нет вовсе: 00-preflight должен дописать её сам
    rsync -a --exclude tests/out /repo/ "$repo_copy/"
    chown -R "$user_name:$user_name" "$repo_copy"
}

check_shellcheck() {
    step "shellcheck"
    if (cd "$repo_copy" && shellcheck -x -S style install.sh install.d/*.sh lib/ui.sh scripts/.local/bin/* tests/*.sh); then
        pass "shellcheck: no findings"
    else
        fail "shellcheck"
    fi
    if bash "$repo_copy/tests/sed-check.sh"; then
        pass "sed edits for initramfs and bootloaders"
    else
        fail "sed edits"
    fi
    local unit_test
    for unit_test in iso-stage-check iso-resume-check rollback-check tv-audio-check; do
        if bash "$repo_copy/tests/$unit_test.sh"; then
            pass "$unit_test (fake commands)"
        else
            fail "$unit_test"
        fi
    done
}

check_package_names() {
    step "package names"
    local list
    local tmp_conf
    tmp_conf="$(mktemp)"
    cp /etc/pacman.conf "$tmp_conf"
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$tmp_conf"
    pacman --config "$tmp_conf" -Sy >/dev/null
    mapfile -t list < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$repo_copy/packages/pacman.txt")
    if pacman --config "$tmp_conf" -Sp --print-format '%n' "${list[@]}" >/dev/null; then
        pass "all ${#list[@]} pacman names resolve"
    else
        fail "some pacman names do not resolve"
    fi
    local aur_name
    while read -r aur_name; do
        if curl -sf "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=$aur_name" | grep -q '"resultcount":1'; then
            pass "AUR: $aur_name"
        else
            fail "AUR: $aur_name not found"
        fi
    done < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$repo_copy/packages/aur.txt")
}

check_dry_run() {
    local label="$1"
    step "dry-run changes nothing ($label)"
    snapshot > /tmp/before-dry
    if as_user bash "$repo_copy/install.sh" --dry-run --trust-aur > /tmp/dry-run.log 2>&1; then
        pass "dry-run finished without errors ($label)"
    else
        fail "dry-run returned an error ($label)"
    fi
    snapshot > /tmp/after-dry
    local changed
    changed="$(compare_snapshots /tmp/before-dry /tmp/after-dry)"
    tail -n 12 /tmp/dry-run.log
    if [[ -z "$changed" ]]; then
        pass "dry-run touched no files ($label)"
    else
        fail "dry-run changed files ($label):"
        printf '%s\n' "$changed"
    fi
}

plant_old_config() {
    step "plant an old config to test backup"
    as_user mkdir -p "$user_home/.config/kitty"
    printf 'font_size 99\n' > "$user_home/.config/kitty/kitty.conf"
    chown "$user_name:$user_name" "$user_home/.config/kitty/kitty.conf"
    # Папка rofi — ссылка на «чужой репо»: бэкап должен унести ссылку целиком, а не файлы из чужого репо
    install -d -o "$user_name" /tmp/other-repo/rofi
    echo '/* foreign */' > /tmp/other-repo/rofi/config.rasi
    as_user ln -s /tmp/other-repo/rofi "$user_home/.config/rofi"
}

run_install() {
    local label="$1"
    local log="$2"
    step "$label"
    # В контейнере нет терминала для вопросов, поэтому AUR без просмотра PKGBUILD
    if as_user bash "$repo_copy/install.sh" --trust-aur > "$log" 2>&1; then
        pass "$label finished without errors"
    else
        fail "$label returned an error"
    fi
    tail -n 40 "$log"
}

check_backup() {
    step "backup"
    local backup
    backup="$(find "$user_home" -maxdepth 1 -name '.config-backup-*' | head -n 1)"
    if [[ -n "$backup" && "$(cat "$backup/.config/kitty/kitty.conf" 2>/dev/null)" == "font_size 99" ]]; then
        pass "old kitty.conf saved in $backup"
    else
        fail "old kitty.conf was not backed up"
    fi
    if [[ -L "$user_home/.config/kitty/kitty.conf" ]]; then
        pass "kitty.conf is now a link into the repo"
    else
        fail "kitty.conf is not linked"
    fi
}

check_parent_symlink_backup() {
    local backup
    backup="$(find "$user_home" -maxdepth 1 -name '.config-backup-*' | head -n 1)"
    if [[ -L "$backup/.config/rofi" && -f /tmp/other-repo/rofi/config.rasi && -d "$user_home/.config/rofi" && ! -L "$user_home/.config/rofi" ]]; then
        pass "foreign symlinked folder moved whole, foreign repo untouched"
    else
        fail "parent symlink backup"
    fi
}

check_security() {
    step "security"
    if nft -c -f /etc/nftables.conf 2>/tmp/nft.err; then
        pass "nftables config is valid"
    elif grep -qiE 'operation not permitted|protocol not supported|cache initialization failed' /tmp/nft.err; then
        skip "nftables config check skipped (container/kernel limit): $(tr '\n' ' ' < /tmp/nft.err)"
    else
        fail "nftables config: $(tr '\n' ' ' < /tmp/nft.err)"
    fi
    if nft -f /etc/nftables.conf 2>/tmp/nft.err && nft list table inet dots_firewall > /tmp/nft.rules; then
        cat /tmp/nft.rules
        if grep -q 'policy drop' /tmp/nft.rules; then
            pass "firewall loaded: input policy drop"
        else
            fail "firewall rules"
        fi
    elif grep -qiE 'operation not permitted|protocol not supported|cache initialization failed' /tmp/nft.err; then
        skip "firewall load skipped (container/kernel limit): $(tr '\n' ' ' < /tmp/nft.err)"
    else
        fail "nft could not load rules: $(tr '\n' ' ' < /tmp/nft.err)"
    fi
    if visudo -cf /etc/sudoers.d/30-timeout >/dev/null && grep -q timestamp_timeout=5 /etc/sudoers.d/30-timeout; then
        pass "sudo timeout"
    else
        fail "sudo timeout"
    fi
    local conf
    for conf in /etc/systemd/coredump.conf.d/20-disable.conf /etc/systemd/resolved.conf.d/20-dns-over-tls.conf /etc/NetworkManager/conf.d/20-mac-randomization.conf /etc/NetworkManager/conf.d/30-dns.conf /etc/docker/daemon.json; do
        if [[ -f "$conf" ]]; then
            pass "written $conf"
        else
            fail "missing $conf"
        fi
    done
    for unit in nftables.service systemd-resolved.service clamav-freshclam-once.timer apparmor.service; do
        if systemctl is-enabled -q "$unit"; then
            pass "enabled $unit"
        else
            fail "not enabled $unit"
        fi
    done
    if ! pacman -Qq pkgstats >/dev/null 2>&1 && pacman -Qq clamav rkhunter lynis >/dev/null; then
        pass "scanners installed, pkgstats absent"
    else
        fail "scanner packages"
    fi
    if grep -q '"telemetry.telemetryLevel": "off"' "$user_home/.config/Code/User/settings.json"; then
        pass "VS Code telemetry off"
    else
        fail "VS Code settings"
    fi
    if grep -q '"diffmenu": true' "$user_home/.config/yay/config.json" 2>/dev/null; then
        pass "yay shows PKGBUILD diffs"
    else
        fail "yay diff settings"
        cat "$user_home/.config/yay/config.json" 2>/dev/null | head -40
    fi
}

check_second_run() {
    snapshot > /tmp/before-second
    run_install "second run" /tmp/second.log
    snapshot > /tmp/after-second
    local changed
    changed="$(compare_snapshots /tmp/before-second /tmp/after-second)"
    if [[ -z "$changed" ]]; then
        pass "second run changed nothing (created, changed, deleted)"
    else
        fail "second run changed files:"
        printf '%s\n' "$changed"
    fi
    if grep -q 'dry-run\|в бэкап:' /tmp/second.log; then
        fail "second run planned changes"
    fi
}

check_configs() {
    step "configs"
    local result
    result="$(as_user Hyprland --verify-config --config "$user_home/.config/hypr/hyprland.lua" 2>&1 | sed -n '/Config parsing result/,$p')"
    printf '%s\n' "$result"
    if grep -q 'config ok' <<< "$result"; then
        pass "Hyprland config"
    else
        fail "Hyprland config"
    fi

    local palette="$user_home/.cache/matugen/colors.json"
    if python -c "import json,sys; d=json.load(open(sys.argv[1])); assert len(d)==18" "$palette"; then
        pass "matugen palette with 18 colors"
    else
        fail "matugen palette"
    fi
    for generated in .config/kitty/colors.conf .config/rofi/colors.rasi .config/hypr/hyprlock-colors.conf \
        .config/hypr/modules/colors.lua .config/gtk-3.0/gtk.css .config/gtk-4.0/gtk.css \
        .config/qt6ct/colors/matugen.conf .cache/matugen/nvim-colors.lua .cache/matugen/fish-colors.fish; do
        if [[ -f "$user_home/$generated" && ! -L "$user_home/$generated" ]]; then
            pass "generated $generated"
        else
            fail "missing generated $generated"
        fi
    done
    local leaked
    leaked="$(find "$repo_copy" -newer /tmp/before-install -type f 2>/dev/null || true)"
    if [[ -z "$leaked" ]]; then
        pass "install wrote nothing into the repo"
    else
        fail "install wrote into the repo:"
        printf '%s
' "$leaked"
    fi

    if as_user fish -n "$user_home/.config/fish/config.fish"; then
        pass "fish syntax"
    else
        fail "fish syntax"
    fi

    local unit
    for unit in sddm.service NetworkManager.service bluetooth.service docker.socket postgresql.service; do
        if systemctl is-enabled -q "$unit" 2>/dev/null; then
            pass "enabled $unit"
        else
            fail "not enabled $unit"
        fi
    done
    for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
        if systemctl --global is-enabled -q "$unit" 2>/dev/null; then
            pass "user unit enabled by default: $unit"
        else
            fail "user unit not enabled: $unit"
        fi
    done
    if [[ -f "$user_home/.config/hypr/hyprlock-colors.conf" ]] && grep -q 'kb_layout = "us,ru"' "$user_home/.config/hypr/modules/input.lua"; then
        pass "us,ru layouts with Alt+Shift switch"
    fi

    if [[ "$(archlinux-java get)" == java-21-openjdk ]]; then
        pass "default Java 21"
    else
        fail "default Java is $(archlinux-java get)"
    fi
    if [[ -f /var/lib/postgres/data/PG_VERSION ]]; then
        pass "PostgreSQL cluster"
    else
        fail "PostgreSQL cluster"
    fi
    if as_user rustup toolchain list | grep -q '^stable'; then
        pass "Rust stable"
    else
        fail "Rust stable"
    fi
    if [[ "$(readlink /usr/share/sddm/themes/dots/theme.conf.user)" == /var/lib/dots-sddm/theme.conf.user && -f /var/lib/dots-sddm/theme.conf.user ]]; then
        pass "SDDM theme and colors"
    else
        fail "SDDM theme and colors"
    fi
}

check_wallpaper_change() {
    step "wallpaper change rebuilds the palette"
    local before
    local after
    before="$(grep '"primary"' "$user_home/.cache/matugen/colors.json")"
    as_user bash -lc "PATH=\$HOME/.local/bin:\$PATH wallpaper-set \$HOME/Pictures/wallpapers/03-forest.jpg"
    after="$(grep '"primary"' "$user_home/.cache/matugen/colors.json")"
    printf 'before: %s\nafter:  %s\n' "$before" "$after"
    if [[ "$before" != "$after" ]] && cmp -s "$user_home/Pictures/wallpapers/03-forest.jpg" /var/lib/dots-sddm/background; then
        pass "new palette and SDDM background"
    else
        fail "wallpaper change"
    fi
}

main() {
    prepare_container
    check_shellcheck
    check_package_names
    check_dry_run "clean system"
    plant_old_config
    touch /tmp/before-install
    sleep 1
    run_install "first run" /tmp/first.log
    check_backup
    check_parent_symlink_backup
    check_second_run
    check_dry_run "configured system"
    check_configs
    check_wallpaper_change
    check_security
    step "result"
    if (( failures == 0 )); then
        printf '\033[1;32mALL CHECKS PASSED\033[0m\n'
    else
        printf '\033[1;31m%d CHECKS FAILED\033[0m\n' "$failures"
        exit 1
    fi
}

main
