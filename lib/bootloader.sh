# shellcheck shell=bash
# Shared kernel command line editing for systemd-boot, Limine and GRUB: diff, .bak copy, typed confirmation.
# This work made by Anfinogentov Nikita
#
# Здесь только функции; их подключают 35-bootloader и 38-apparmor. Нужен уже подключённый lib/ui.sh.

# patch_file возвращает: 0 — изменено, 1 — менять нечего или отказ, 2 — ошибка.
# Показываю правку как diff, применяю только после ввода «да»; без удачной копии .bak не пишу.
patch_file() {
    local target="$1"
    local sed_script="$2"
    local rescue_kind="${3:-}"
    local preview
    preview="$(mktemp)" || return 2
    if ! sudo cat "$target" | tee "$preview" >/dev/null; then
        oops "не смог прочитать $target"
        rm -f "$preview"
        return 2
    fi
    if ! sed -i -E "$sed_script" "$preview"; then
        rm -f "$preview"
        return 2
    fi
    if sudo cmp -s "$target" "$preview"; then
        good "в $target уже всё есть"
        rm -f "$preview"
        return 1
    fi
    say "правка в $target:"
    sudo diff -u "$target" "$preview" || true
    if ! ask_exact "Применить эту правку загрузчика?" "да"; then
        say "оставляю $target как есть"
        rm -f "$preview"
        return 1
    fi
    if ! sudo cp -a "$target" "$target.bak-$(date +%Y%m%d-%H%M%S)"; then
        oops "не смог сделать копию $target, ничего не меняю"
        rm -f "$preview"
        return 2
    fi
    if [[ -n "$rescue_kind" ]] && ! prepare_rescue "$target" "$preview" "$rescue_kind"; then
        oops "не смог создать rescue-запись; $target не меняю"
        rm -f "$preview"
        return 2
    fi
    if ! sudo cp "$preview" "$target"; then
        oops "не смог записать $target; копия лежит рядом с ним (.bak-…)"
        rm -f "$preview"
        return 2
    fi
    rm -f "$preview"
    good "$target изменён, копия лежит рядом"
}

# Здесь я сохраняю исходные параметры до первой правки; rescue никогда не обновляю новыми параметрами.
prepare_rescue() {
    local target="$1"
    local preview="$2"
    local kind="$3"
    local rescue="${target%.conf}-rescue.conf"
    local draft
    local original
    draft="$(mktemp)" || return 1
    if [[ "$kind" == systemd ]]; then
        if sudo test -e "$rescue"; then
            rm -f "$draft"
            return 0
        fi
        if ! sudo cat "$target" | awk '
            /^title[[:space:]]+/ { $0 = $0 " (rescue)"; title = 1 }
            /^options[[:space:]]+/ {
                gsub(/[[:space:]]+systemd.unit=[^[:space:]]+/, "")
                $0 = $0 " systemd.unit=multi-user.target"; options = 1
            }
            { print }
            END { if (!title) print "title Arch Linux (rescue)"; if (!options) exit 1 }
        ' > "$draft"; then
            rm -f "$draft"
            return 1
        fi
    elif [[ "$kind" == limine ]]; then
        # Здесь я добавляю копии пунктов в само меню: отдельный .conf Limine автоматически не читает.
        if grep -qxF '# dots-rescue' "$preview"; then
            rm -f "$draft"
            return 0
        fi
        if ! sudo cat "$target" | awk '
            function emit() { if (cmdline) { printf "%s", entry; found = 1 } }
            /^\// { emit(); entry = "/" $0; sub(/^\/+/, "/", entry); entry = entry " (rescue)\n"; cmdline = 0; next }
            /^[[:space:]]*(kernel_)?cmdline:/ {
                gsub(/[[:space:]]+systemd.unit=[^[:space:]]+/, "")
                $0 = $0 " systemd.unit=multi-user.target"; cmdline = 1
            }
            { if (entry != "") entry = entry $0 "\n" }
            END { emit(); if (!found) exit 1 }
        ' > "$draft"; then
            rm -f "$draft"
            return 1
        fi
        if ! printf '\n# dots-rescue\n' >> "$preview" || ! cat "$draft" >> "$preview"; then
            rm -f "$draft"
            return 1
        fi
    else
        rescue=/boot/grub/dots-rescue.conf
        if sudo test -e "$rescue"; then
            rm -f "$draft"
            return 0
        fi
        # Здесь я использую штатный 41_custom, чтобы сохранённое меню было доступно после grub-mkconfig.
        if ! sudo test -x /etc/grub.d/41_custom || ! sudo cat /boot/grub/grub.cfg | sed -E \
            '/^[[:space:]]*linux(efi|16)?[[:space:]]+/ { s/[[:space:]]+systemd.unit=[^[:space:]]+//g; s/$/ systemd.unit=multi-user.target/; }' > "$draft"; then
            rm -f "$draft"
            return 1
        fi
        if ! grep -Eq '^[[:space:]]*linux(efi|16)?[[:space:]]+' "$draft"; then
            rm -f "$draft"
            return 1
        fi
        original=""
        if sudo test -e /boot/grub/custom.cfg; then
            original="$(sudo cat /boot/grub/custom.cfg)" || { rm -f "$draft"; return 1; }
        fi
        if ! write_file_root /boot/grub/custom.cfg "$original
menuentry 'Arch Linux (rescue)' {
    configfile \$prefix/dots-rescue.conf
}"; then
            rm -f "$draft"
            return 1
        fi
    fi
    if ! sudo install -m 600 "$draft" "$rescue.tmp" || ! sudo mv "$rescue.tmp" "$rescue"; then
        rm -f "$draft"
        return 1
    fi
    rm -f "$draft"
    good "rescue сохранён: $rescue (systemd.unit=multi-user.target)"
}

# Вызов patch_file с разбором кода: ошибка (2) пробрасывается наверх
apply_patch() {
    local status=0
    patch_file "$1" "$2" "${3:-}" || status=$?
    if (( status == 2 )); then
        return 1
    fi
    return 0
}

# Записи systemd-boot лежат в $BOOT: это ESP или отдельный раздел XBOOTLDR
# Второй аргумент 1: записей может не быть (ядро уже настроено через UKI), это не ошибка
patch_systemd_boot() {
    local param="$1"
    local allow_empty="${2:-0}"
    local boot_dir
    local entry
    local entries=()
    boot_dir="$(sudo bootctl --print-boot-path 2>/dev/null || sudo bootctl --print-esp-path)" || return 1
    # Список записей сначала читаю в массив: цикл `while read ... < <(find)` занимал stdin,
    # и вопрос «да» внутри него видел «нет терминала» и молча пропускал правку
    local listing
    if [[ "$allow_empty" == 1 ]] && ! sudo test -d "$boot_dir/loader/entries"; then
        return 0
    fi
    listing="$(sudo find "$boot_dir/loader/entries" -maxdepth 1 -type f -name '*.conf' ! -name '*-rescue.conf')" || return 1
    mapfile -t entries <<< "$listing"
    if [[ -z "$listing" ]]; then
        if [[ "$allow_empty" == 1 ]]; then
            return 0
        fi
        oops "не нашёл записей в $boot_dir/loader/entries; если ядро загружается через UKI, параметры задаются в /etc/kernel/cmdline"
        return 1
    fi
    for entry in "${entries[@]}"; do
        apply_patch "$entry" "/^options[[:space:]]+/ { /[[:space:]]${param//./\\.}([[:space:]]|\$)/! s/\$/ $param/ }" systemd || return 1
    done
}

patch_limine() {
    local conf="$1"
    local param="$2"
    apply_patch "$conf" "/^# dots-rescue\$/,\$ b; /^[[:space:]]*(kernel_)?cmdline:[[:space:]]*/ { /[[:space:]]${param//./\\.}([[:space:]]|\$)/! s/\$/ $param/ }" limine
}

patch_grub() {
    local param="$1"
    local status=0
    patch_file /etc/default/grub "/^GRUB_CMDLINE_LINUX_DEFAULT=/ { /[[:space:]\"]${param//./\\.}([[:space:]\"])/! s/\"\$/ $param\"/ }" grub || status=$?
    if (( status == 2 )); then
        return 1
    fi
    if (( status == 0 )); then
        sudo grub-mkconfig -o /boot/grub/grub.cfg || return 1
    fi
    return 0
}

# UKI собирает mkinitcpio: параметры ядра зашиты в сам .efi и берутся из /etc/kernel/cmdline.
# Пути можно подменить (нужно тестам), по умолчанию — системные.
kernel_cmdline_file="${DOTS_KERNEL_CMDLINE:-/etc/kernel/cmdline}"
mkinitcpio_preset_dir="${DOTS_PRESET_DIR:-/etc/mkinitcpio.d}"

# UKI включён, если в каком-то пресете mkinitcpio есть незакомментированная строка *_uki=
uses_uki() {
    grep -qsE '^[[:space:]]*[A-Za-z0-9_]+_uki=' "$mkinitcpio_preset_dir"/*.preset
}

# sed для /etc/kernel/cmdline. Если ключ (например lsm=) уже есть с другим значением, я его заменяю:
# второй lsm= в той же строке сделал бы порядок модулей неочевидным
uki_cmdline_sed() {
    local param="$1"
    local key="${param%%=*}"
    local key_re="${key//./\\.}"
    printf '1 { /(^|[[:space:]])%s(=|[[:space:]]|$)/ { s/(^|[[:space:]])%s(=[^[:space:]]*)?([[:space:]]|$)/\\1%s\\3/; b }; s/$/ %s/; s/^ // }' \
        "$key_re" "$key_re" "$param" "$param"
}

patch_uki() {
    local param="$1"
    local status=0
    if ! sudo test -f "$kernel_cmdline_file"; then
        oops "UKI есть, но нет $kernel_cmdline_file; создайте его (можно из /proc/cmdline) и запустите шаг снова"
        return 1
    fi
    # Если в пресете задан --cmdline, mkinitcpio берёт параметры оттуда, а не из файла
    if grep -qsE '^[^#]*--cmdline' "$mkinitcpio_preset_dir"/*.preset; then
        oops "в пресете mkinitcpio задан --cmdline: $kernel_cmdline_file не используется, ничего не меняю"
        return 1
    fi
    patch_file "$kernel_cmdline_file" "$(uki_cmdline_sed "$param")" || status=$?
    if (( status == 2 )); then
        return 1
    fi
    if (( status == 0 )); then
        # Здесь я пересобираю все UKI, fallback тоже; старые параметры остаются в копии .bak
        say "пересобираю UKI: mkinitcpio -P"
        if ! sudo mkinitcpio -P; then
            oops "mkinitcpio -P упал; вернуть параметры: копия ${kernel_cmdline_file}.bak-… и снова mkinitcpio -P"
            return 1
        fi
    fi
    return 0
}

find_limine_conf() {
    local candidate
    for candidate in /boot/limine.conf /boot/limine/limine.conf /efi/limine.conf /boot/EFI/limine/limine.conf /efi/EFI/limine/limine.conf; do
        if sudo test -f "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

add_kernel_param() {
    local param="$1"
    local limine_conf
    # UKI проверяю первым: при нём записей в loader/entries обычно нет, а параметры живут в $kernel_cmdline_file
    if uses_uki; then
        say "ядро загружается через UKI: параметры в $kernel_cmdline_file"
        patch_uki "$param" || return 1
        # Обычные записи systemd-boot рядом с UKI тоже правлю, если они есть
        if sudo bootctl is-installed >/dev/null 2>&1; then
            patch_systemd_boot "$param" 1
        fi
    elif sudo bootctl is-installed >/dev/null 2>&1; then
        say "загрузчик: systemd-boot"
        patch_systemd_boot "$param"
    elif limine_conf="$(find_limine_conf)"; then
        say "загрузчик: Limine ($limine_conf)"
        patch_limine "$limine_conf" "$param"
    elif [[ -f /etc/default/grub ]]; then
        say "загрузчик: GRUB"
        patch_grub "$param"
    else
        oops "не смог определить загрузчик, ничего не менял"
        return 1
    fi
}
