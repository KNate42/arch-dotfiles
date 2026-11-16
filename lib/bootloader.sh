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
    if ! sudo cp "$preview" "$target"; then
        oops "не смог записать $target; копия лежит рядом с ним (.bak-…)"
        rm -f "$preview"
        return 2
    fi
    rm -f "$preview"
    good "$target изменён, копия лежит рядом"
}

# Вызов patch_file с разбором кода: ошибка (2) пробрасывается наверх
apply_patch() {
    local status=0
    patch_file "$1" "$2" || status=$?
    if (( status == 2 )); then
        return 1
    fi
    return 0
}

# Записи systemd-boot лежат в $BOOT: это ESP или отдельный раздел XBOOTLDR
patch_systemd_boot() {
    local param="$1"
    local boot_dir
    local entry
    local found=0
    boot_dir="$(sudo bootctl --print-boot-path 2>/dev/null || sudo bootctl --print-esp-path)"
    while IFS= read -r entry; do
        found=1
        apply_patch "$entry" "/^options / { / ${param//./\\.}( |\$)/! s/\$/ $param/ }" || return 1
    done < <(sudo find "$boot_dir/loader/entries" -name '*.conf' 2>/dev/null)
    if (( found == 0 )); then
        oops "не нашёл записей в $boot_dir/loader/entries; если ядро загружается через UKI, параметры задаются в /etc/kernel/cmdline"
        return 1
    fi
}

patch_limine() {
    local conf="$1"
    local param="$2"
    apply_patch "$conf" "/^[[:space:]]*(kernel_)?cmdline:/ { / ${param//./\\.}( |\$)/! s/\$/ $param/ }"
}

patch_grub() {
    local param="$1"
    local status=0
    patch_file /etc/default/grub "/^GRUB_CMDLINE_LINUX_DEFAULT=/ { / ${param//./\\.}[ \"]/! s/\"\$/ $param\"/ }" || status=$?
    if (( status == 2 )); then
        return 1
    fi
    if (( status == 0 )); then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
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
    if sudo bootctl is-installed >/dev/null 2>&1; then
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
