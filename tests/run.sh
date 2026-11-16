#!/usr/bin/env bash
# Starts a fresh archlinux container (official image) and runs tests/container-test.sh inside it.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
container_name="dots-install-test"
out_dir="$repo_dir/tests/out"

main() {
    if ! command -v docker >/dev/null 2>&1; then
        printf 'Ooops.. docker is not installed\n' >&2
        exit 1
    fi
    mkdir -p "$out_dir"
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    docker pull archlinux:latest
    # Здесь я монтирую репо только для чтения: тест работает с копией внутри контейнера.
    # NET_ADMIN нужен, чтобы загрузить правила nftables и посмотреть их
    docker run --name "$container_name" --cap-add NET_ADMIN -v "$repo_dir:/repo:ro" archlinux:latest \
        bash -c 'pacman -Sy --noconfirm --needed rsync >/dev/null && bash /repo/tests/container-test.sh' \
        2>&1 | tee "$out_dir/container-test.log"
}

main "$@"
