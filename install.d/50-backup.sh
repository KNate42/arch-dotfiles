#!/usr/bin/env bash
# Moves existing configs that would block stow (and files the installer will overwrite) into ~/.config-backup-<date>.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
# Метка установки и журнал отката живут в ~/.local/state, не в кэше: чистка кэша не должна их стирать
state_dir="$HOME/.local/state/dots"
# Метка первого успешного раскладывания: после неё сгенерированные файлы уже наши и в бэкап не идут
linked_marker="$state_dir/linked"
matugen_config="$repo_dir/matugen/.config/matugen/config.toml"
# Файлы, которые пишет сам установщик (60-theme), а не stow
installer_outputs=(.config/qt5ct/qt5ct.conf .config/qt6ct/qt6ct.conf)

planned=()

# Ссылка, которая уже ведёт в репо, — это наш прошлый запуск, её не трогаю
is_ours() {
    local target="$1"
    local source_file="$2"
    [[ -L "$target" ]] && [[ "$(realpath -m "$target")" == "$(realpath -m "$source_file")" ]]
}

already_planned() {
    local rel="$1"
    local item
    for item in "${planned[@]}"; do
        if [[ "$rel" == "$item" || "$rel" == "$item"/* ]]; then
            return 0
        fi
    done
    return 1
}

# Здесь я иду по пути сверху вниз. Если папка по дороге — ссылка или обычный файл, уношу её целиком
# и внутрь не захожу: иначе mv вытащил бы файл из чужого репо, на который смотрит ссылка.
plan_path() {
    local rel="$1"
    local prefix=""
    local part
    local parts=()
    IFS='/' read -r -a parts <<< "$rel"
    local last=$(( ${#parts[@]} - 1 ))
    local i
    for (( i = 0; i < last; i++ )); do
        part="${parts[$i]}"
        prefix="${prefix:+$prefix/}$part"
        if [[ -L "$HOME/$prefix" || ( -e "$HOME/$prefix" && ! -d "$HOME/$prefix" ) ]]; then
            if ! already_planned "$prefix"; then
                planned+=("$prefix")
            fi
            return 0
        fi
        if [[ ! -e "$HOME/$prefix" ]]; then
            return 0
        fi
    done
    if [[ -e "$HOME/$rel" || -L "$HOME/$rel" ]] && ! already_planned "$rel"; then
        planned+=("$rel")
    fi
}

# Пути, куда пишет matugen (output_path из config.toml), относительно домашней папки
matugen_outputs() {
    sed -n 's/^output_path = "~\/\(.*\)"$/\1/p' "$matugen_config"
}

# Журнал пишу до переноса и дополняю после каждого mv: если что-то упадёт посередине,
# и этот шаг, и 55-stow знают, что именно уже унесено, и могут вернуть всё на место.
journal="$state_dir/last-backup"

start_journal() {
    mkdir -p "$state_dir"
    printf '%s\n' "$backup_dir" > "$journal"
}

# Возвращаю унесённое по журналу; место должно быть свободно, чужое не перезаписываю
rollback_moves() {
    local rel
    while IFS= read -r rel; do
        if [[ -n "$rel" && ( -e "$backup_dir/$rel" || -L "$backup_dir/$rel" ) && ! -e "$HOME/$rel" && ! -L "$HOME/$rel" ]]; then
            mkdir -p "$(dirname "$HOME/$rel")"
            mv "$backup_dir/$rel" "$HOME/$rel"
        fi
    done < <(tail -n +2 "$journal")
    rm -f "$journal"
}

# mv переносит саму ссылку, а не то, на что она указывает, поэтому чужие и битые ссылки сохраняются как есть
move_planned() {
    local rel
    if [[ "$dry_run" == 1 ]]; then
        for rel in "${planned[@]}"; do
            say "в бэкап: ~/$rel"
            run_cmd mv "$HOME/$rel" "$backup_dir/$rel"
        done
        return 0
    fi
    start_journal
    for rel in "${planned[@]}"; do
        say "в бэкап: ~/$rel"
        if ! mkdir -p "$backup_dir/$(dirname "$rel")" || ! mv "$HOME/$rel" "$backup_dir/$rel"; then
            oops "не смог убрать ~/$rel в бэкап; возвращаю уже унесённое"
            rollback_moves
            return 1
        fi
        printf '%s\n' "$rel" >> "$journal"
    done
}

main() {
    local packages=()
    local pkg
    local source_file
    local rel
    mapfile -t packages < <(read_list "$repo_dir/packages/stow.txt")

    # Без stow старые конфиги уносить нельзя: на их место потом нечего положить
    if ! command -v stow >/dev/null 2>&1 && [[ "$dry_run" == 0 ]]; then
        oops "нет stow: сначала нужен шаг 10-base, конфиги не трогаю"
        return 1
    fi

    for pkg in "${packages[@]}"; do
        if [[ ! -d "$repo_dir/$pkg" ]]; then
            warn "в репо нет пакета stow $pkg"
            continue
        fi
        while IFS= read -r -d '' source_file; do
            rel="${source_file#"$repo_dir/$pkg/"}"
            if ! is_ours "$HOME/$rel" "$source_file"; then
                plan_path "$rel"
            fi
        done < <(find "$repo_dir/$pkg" \( -type f -o -type l \) -print0)
    done

    if [[ ! -f "$linked_marker" ]]; then
        while IFS= read -r rel; do
            plan_path "$rel"
        done < <(matugen_outputs; printf '%s\n' "${installer_outputs[@]}")
    fi

    if (( ${#planned[@]} == 0 )); then
        good "бэкапить нечего"
        return 0
    fi
    move_planned || return 1
    good "перенесено объектов: ${#planned[@]}, в $backup_dir"
}

main
