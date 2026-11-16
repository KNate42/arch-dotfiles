#!/usr/bin/env bash
# Prepares the dev stack: docker group and socket, PostgreSQL cluster, Rust stable, default Java 21, npm prefix.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

default_java="java-21-openjdk"
pg_data="/var/lib/postgres/data"

enable_unit() {
    local unit="$1"
    if systemctl is-enabled -q "$unit" 2>/dev/null; then
        good "$unit уже включена"
    else
        run_cmd sudo systemctl enable "$unit"
    fi
}

setup_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        warn "docker не установлен, пропускаю"
        return 0
    fi
    enable_unit docker.socket
    if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        good "$USER уже в группе docker"
    else
        run_cmd sudo usermod -aG docker "$USER"
        say "группа docker заработает после нового входа в систему"
    fi
}

# Здесь я создаю кластер PostgreSQL один раз; на btrfs сначала выключаю copy-on-write для папки данных
setup_postgres() {
    if ! command -v initdb >/dev/null 2>&1; then
        warn "postgresql не установлен, пропускаю"
        return 0
    fi
    if [[ "$dry_run" == 1 ]]; then
        say "[dry-run] проверил бы кластер PostgreSQL и при нужде создал его (initdb)"
    elif sudo test -f "$pg_data/PG_VERSION"; then
        good "кластер PostgreSQL уже создан"
    else
        run_cmd sudo install -d -o postgres -g postgres -m 700 "$pg_data"
        if [[ "$(stat -f -c %T /var/lib/postgres 2>/dev/null)" == btrfs ]]; then
            run_cmd sudo chattr +C "$pg_data"
        fi
        run_cmd sudo -iu postgres initdb -D "$pg_data"
    fi
    enable_unit postgresql.service
}

setup_rust() {
    if ! command -v rustup >/dev/null 2>&1; then
        warn "rustup не установлен, пропускаю"
        return 0
    fi
    if rustup toolchain list 2>/dev/null | grep -q '^stable'; then
        good "Rust stable уже стоит"
    else
        run_cmd rustup default stable
    fi
}

setup_java() {
    if ! command -v archlinux-java >/dev/null 2>&1; then
        warn "JDK не установлен, пропускаю"
        return 0
    fi
    if [[ "$(archlinux-java get 2>/dev/null)" == "$default_java" ]]; then
        good "Java по умолчанию — $default_java"
    else
        run_cmd sudo archlinux-java set "$default_java"
    fi
}

# npm без sudo: глобальные пакеты идут в ~/.local, оттуда же их видит PATH
setup_npm() {
    if ! command -v npm >/dev/null 2>&1; then
        return 0
    fi
    # Читаю ~/.npmrc сам, без вызова npm: npm при каждом запуске пишет и чистит свои журналы
    if grep -qxF "prefix=$HOME/.local" "$HOME/.npmrc" 2>/dev/null; then
        good "npm ставит глобальные пакеты в ~/.local"
    else
        run_cmd npm config set prefix "$HOME/.local"
    fi
}

main() {
    setup_docker
    setup_postgres
    setup_rust
    setup_java
    setup_npm
}

main
