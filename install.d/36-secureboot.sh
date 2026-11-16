#!/usr/bin/env bash
# Optional (--secure-boot): own Secure Boot keys with sbctl, signs systemd-boot, every kernel and UKI.
# Needs the firmware in Setup Mode; asks for a typed "да" before touching the keys.
# Advises turning Secure Boot on only after keys are enrolled and sbctl verify finds nothing unsigned.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

systemd_boot_efi="/usr/lib/systemd/boot/efi/systemd-bootx64.efi"
# Метка, что ключи именно записаны в прошивку: поле Installed у sbctl значит только «ключи созданы на диске»
enrolled_marker="/var/lib/sbctl/dots-enrolled"

explain_risk() {
    warn "Secure Boot со своими ключами — по Arch Wiki (UEFI/Secure Boot, раздел sbctl)."
    warn "Риск: если прошивка поведёт себя нестандартно, компьютер не загрузится, пока Secure Boot не выключить в BIOS."
    warn "Откат: выключить Secure Boot в настройках прошивки — система загрузится как раньше, подписи ничему не мешают."
    warn "Ключи Microsoft добавляются тоже (-m): без них прошивка видеокарты может не запуститься и экран останется чёрным."
}

status_field() {
    sudo sbctl status --json | jq -r ".$1"
}

ensure_keys() {
    if [[ "$(status_field installed)" == true ]]; then
        good "ключи sbctl уже созданы"
        return 0
    fi
    sudo sbctl create-keys
}

# Записываю ключи, если прошивка в Setup Mode и нашей метки нет (или прошивку сбросили после записи)
ensure_enrolled() {
    local setup_mode
    setup_mode="$(status_field setup_mode)"
    if [[ -f "$enrolled_marker" && "$setup_mode" == false ]]; then
        good "ключи записаны в прошивку"
        return 0
    fi
    if [[ "$setup_mode" != true ]]; then
        oops "прошивка не в Setup Mode, а записи наших ключей нет: в BIOS сбросьте ключи Secure Boot (Reset to Setup Mode / Clear keys) и запустите снова"
        return 1
    fi
    if ! ask_exact "Записать свои ключи Secure Boot (и ключи Microsoft) в прошивку?" "да"; then
        say "ключи в прошивку не записываю"
        return 1
    fi
    sudo sbctl enroll-keys -m
    if [[ "$(status_field setup_mode)" != false ]]; then
        oops "после enroll-keys прошивка всё ещё в Setup Mode — ключи не записались"
        return 1
    fi
    sudo touch "$enrolled_marker"
    good "ключи записаны в прошивку"
}

# Всё, что прошивка и systemd-boot запускают при загрузке: загрузчик, все ядра, все UKI
boot_images() {
    local esp
    local boot
    esp="$(sudo bootctl --print-esp-path)"
    boot="$(sudo bootctl --print-boot-path)"
    printf '%s\n' "$esp/EFI/systemd/systemd-bootx64.efi" "$esp/EFI/BOOT/BOOTX64.EFI"
    sudo find "$boot" -maxdepth 1 -name 'vmlinuz-*' -type f
    sudo find "$esp/EFI/Linux" "$boot/EFI/Linux" -maxdepth 1 -name '*.efi' -type f 2>/dev/null || true
}

sign_all() {
    local image
    local report
    # Подписанная копия для bootctl: при обновлении systemd-boot ставится уже подписанный файл
    if [[ ! -f "$systemd_boot_efi.signed" ]]; then
        sudo sbctl sign -s -o "$systemd_boot_efi.signed" "$systemd_boot_efi"
    fi
    report="$(sudo sbctl verify 2>&1 || true)"
    while IFS= read -r image; do
        if ! sudo test -f "$image"; then
            continue
        fi
        if grep -qF "$image is signed" <<< "$report"; then
            good "$image уже подписан"
        else
            sudo sbctl sign -s "$image"
        fi
    done < <(boot_images | sort -u)
}

# Включать Secure Boot советую, только если sbctl verify не нашёл ни одного неподписанного файла
verify_all() {
    local report
    local verify_status=0
    report="$(sudo sbctl verify 2>&1)" || verify_status=$?
    printf '%s\n' "$report"
    if (( verify_status != 0 )) || grep -q 'is not signed' <<< "$report"; then
        oops "есть неподписанные файлы (см. выше): Secure Boot пока не включайте"
        return 1
    fi
    good "все загрузочные файлы подписаны"
}

main() {
    if [[ "$want_secure_boot" != 1 ]]; then
        say "пропускаю Secure Boot (включить: --secure-boot)"
        return 0
    fi
    explain_risk
    if [[ "$dry_run" == 1 ]]; then
        say "[dry-run] поставил бы sbctl, создал ключи, записал их в прошивку (после «да»), подписал загрузчик, все ядра и UKI и проверил sbctl verify"
        return 0
    fi
    if ! pacman -Qq sbctl >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm sbctl
    fi
    ensure_keys
    ensure_enrolled
    sign_all
    verify_all
    say "дальше: включите Secure Boot в BIOS и после загрузки проверьте: sbctl status (Secure Boot: Enabled)"
    say "модули Nvidia из DKMS не подписываются: штатное ядро Arch не требует подписи модулей — проверьте, что после включения есть картинка"
}

main
