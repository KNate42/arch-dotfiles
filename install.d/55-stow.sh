#!/usr/bin/env bash
# Links every stow package from packages/stow.txt into $HOME (files only, folders stay real).
# If stow fails, puts back what 50-backup moved away (and on the first install removes partial links).
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

# Метка установки и журнал отката живут в ~/.local/state, не в кэше: чистка кэша не должна их стирать
state_dir="$HOME/.local/state/dots"
last_backup="$state_dir/last-backup"
linked_marker="$state_dir/linked"

# Возвращаю на место только то, что унёс последний бэкап, и только если место свободно
restore_backup() {
    local backup_dir
    local rel
    if [[ ! -f "$last_backup" ]]; then
        return 0
    fi
    backup_dir="$(head -n 1 "$last_backup")"
    while IFS= read -r rel; do
        if [[ -z "$rel" ]]; then
            continue
        fi
        if [[ -e "$backup_dir/$rel" || -L "$backup_dir/$rel" ]] && [[ ! -e "$HOME/$rel" && ! -L "$HOME/$rel" ]]; then
            mkdir -p "$(dirname "$HOME/$rel")"
            mv "$backup_dir/$rel" "$HOME/$rel"
        fi
    done < <(tail -n +2 "$last_backup")
    rm -f "$last_backup"
    warn "вернул старые конфиги из $backup_dir"
}

main() {
    local packages=()
    mapfile -t packages < <(read_list "$repo_dir/packages/stow.txt")

    # Любая ошибка до конца раскладки ведёт к возврату унесённых конфигов, а не к обрыву шага
    if ! command -v stow >/dev/null 2>&1 && [[ "$dry_run" == 0 ]]; then
        oops "нет stow: сначала нужен шаг 10-base"
        restore_backup
        return 1
    fi
    if ! run_cmd chmod +x "$repo_dir"/scripts/.local/bin/*; then
        oops "не смог сделать скрипты исполняемыми"
        restore_backup
        return 1
    fi
    # Здесь я не даю stow сворачивать папки в ссылки: тогда файлы matugen не попадут в репо
    if ! run_cmd stow --no-folding --restow --dir "$repo_dir" --target "$HOME" "${packages[@]}"; then
        oops "stow не смог разложить конфиги"
        # При первой установке убираю частичные ссылки; при повторной ссылки прошлого запуска рабочие, их оставляю.
        # Унесённое этим запуском возвращаю в обоих случаях — только на свободные места.
        if [[ ! -f "$linked_marker" ]]; then
            stow --no-folding --delete --dir "$repo_dir" --target "$HOME" "${packages[@]}" 2>/dev/null || true
        fi
        restore_backup
        return 1
    fi
    if [[ "$dry_run" == 0 ]]; then
        if [[ ! -f "$linked_marker" ]]; then
            mkdir -p "$state_dir"
            touch "$linked_marker"
        fi
        rm -f "$last_backup"
    fi
    good "разложено ссылками: ${packages[*]}"
}

main
