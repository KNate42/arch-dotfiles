# shellcheck shell=bash
# Shared helpers for install modules: output, dry-run aware runner, confirmations, small file edits.
# This work made by Anfinogentov Nikita
#
# Здесь я держу только функции. Состояния нет: флаги каждый модуль разбирает сам
# через parse_flags, а функции читают переменную dry_run модуля, который их вызвал.

say() {
    printf '\033[1;34m::\033[0m %s\n' "$*"
}

good() {
    printf '\033[1;32m ok\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m !!\033[0m %s\n' "$*" >&2
}

oops() {
    printf '\033[1;31mOoops..\033[0m %s\n' "$*" >&2
}

# Здесь я разбираю общие флаги модуля: --dry-run и --bootloader.
parse_flags() {
    dry_run=0
    # Эти флаги читают отдельные модули (35-bootloader, 36-secureboot, 38-apparmor, 15-yay, 20-aur)
    # shellcheck disable=SC2034
    want_bootloader=0
    # shellcheck disable=SC2034
    want_apparmor_d=0
    # shellcheck disable=SC2034
    want_secure_boot=0
    # shellcheck disable=SC2034
    trust_aur=0
    local arg
    # shellcheck disable=SC2034
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=1 ;;
            --bootloader) want_bootloader=1 ;;
            --apparmor-d) want_apparmor_d=1 ;;
            --secure-boot) want_secure_boot=1 ;;
            --trust-aur) trust_aur=1 ;;
            *) ;;
        esac
    done
}

# Выполняет команду, а в режиме --dry-run только печатает её.
run_cmd() {
    if [[ "${dry_run:-0}" == 1 ]]; then
        printf '\033[2m[dry-run]\033[0m %s\n' "$*"
        return 0
    fi
    "$@"
}

# Спрашивает да/нет. В dry-run и без терминала ответ всегда «нет».
ask_yes() {
    local question="$1"
    local answer
    if [[ "${dry_run:-0}" == 1 ]]; then
        printf '\033[2m[dry-run]\033[0m спросил бы: %s — считаю «нет»\n' "$question"
        return 1
    fi
    if [[ ! -t 0 ]]; then
        warn "нет терминала, на вопрос «$question» отвечаю «нет»"
        return 1
    fi
    read -r -p "$question [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "да" ]]
}

# Строгое подтверждение для опасных действий: надо ввести слово целиком.
ask_exact() {
    local question="$1"
    local expected="$2"
    local answer
    if [[ "${dry_run:-0}" == 1 || ! -t 0 ]]; then
        printf '\033[2m[dry-run]\033[0m спросил бы: %s — пропускаю\n' "$question"
        return 1
    fi
    # В консоли установочного образа раскладка английская, поэтому вместо «да» принимаю и yes
    if [[ "$expected" == "да" ]]; then
        read -r -p "$question (введите «да» или yes): " answer
        [[ "$answer" == "да" || "$answer" == "yes" ]]
        return
    fi
    read -r -p "$question (введите «$expected»): " answer
    [[ "$answer" == "$expected" ]]
}

# Читает список пакетов: без комментариев и пустых строк.
read_list() {
    local list_file="$1"
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$list_file"
}

# Добавляет строку в системный файл, если её там ещё нет.
append_line_root() {
    local line="$1"
    local target="$2"
    if grep -qxF -- "$line" "$target" 2>/dev/null; then
        return 0
    fi
    if [[ "${dry_run:-0}" == 1 ]]; then
        printf '\033[2m[dry-run]\033[0m добавил бы в %s: %s\n' "$target" "$line"
        return 0
    fi
    printf '%s\n' "$line" | sudo tee -a "$target" >/dev/null
}

# Записывает содержимое в системный файл, только если оно отличается.
write_file_root() {
    local target="$1"
    local content="$2"
    if [[ -r "$target" ]] && [[ "$(cat "$target")" == "$content" ]]; then
        return 0
    fi
    if [[ "${dry_run:-0}" == 1 ]]; then
        printf '\033[2m[dry-run]\033[0m записал бы %s:\n%s\n' "$target" "$content"
        return 0
    fi
    sudo mkdir -p "$(dirname "$target")"
    printf '%s\n' "$content" | sudo tee "$target" >/dev/null
}


# Показывает PKGBUILD из AUR и спрашивает, собирать ли пакет. С --trust-aur молча соглашается.
# В AUR пакеты заливает кто угодно, поэтому без просмотра сборочный скрипт не запускаю.
review_pkgbuild() {
    local pkg_dir="$1"
    local pkg_name="$2"
    local build_file
    if [[ "${trust_aur:-0}" == 1 ]]; then
        warn "--trust-aur: собираю $pkg_name без просмотра PKGBUILD"
        return 0
    fi
    if [[ "${dry_run:-0}" == 1 ]]; then
        printf '\033[2m[dry-run]\033[0m показал бы PKGBUILD пакета %s и спросил, собирать ли\n' "$pkg_name"
        return 0
    fi
    for build_file in "$pkg_dir"/PKGBUILD "$pkg_dir"/*.install; do
        if [[ -f "$build_file" ]]; then
            printf '\n\033[1m===== %s: %s =====\033[0m\n' "$pkg_name" "$(basename "$build_file")"
            cat "$build_file"
        fi
    done
    printf '\n'
    ask_yes "Это PKGBUILD пакета $pkg_name из AUR. Всё в порядке, собирать?"
}

# Внутри arch-chroot при установке с образа. systemd-detect-virt --chroot от обычного пользователя
# ошибается, поэтому главный признак — флаг DOTS_CHROOT=1, который ставит 05-from-iso.
in_chroot() {
    [[ "${DOTS_CHROOT:-0}" == 1 ]] || systemd-detect-virt --chroot >/dev/null 2>&1
}
