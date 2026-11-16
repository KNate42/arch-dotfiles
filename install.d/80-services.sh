#!/usr/bin/env bash
# Enables system services: network, bluetooth and the SDDM login screen.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

enable_unit() {
    local unit="$1"
    if systemctl is-enabled -q "$unit" 2>/dev/null; then
        good "$unit уже включена"
    else
        run_cmd sudo systemctl enable "$unit"
    fi
}

# Здесь я не включаю SDDM поверх другого экрана входа: два сразу systemd не разрешит
enable_login_screen() {
    local current
    current="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    if [[ -n "$current" && "$current" != *sddm.service ]]; then
        warn "включён другой экран входа ($current); выключите его и запустите шаг снова"
        return 1
    fi
    enable_unit sddm.service
}

main() {
    enable_unit NetworkManager.service
    enable_unit bluetooth.service
    enable_login_screen
}

main
