#!/usr/bin/env bash
# Checks the risky sed edits (mkinitcpio hooks, kernel command lines) on sample files, twice each for idempotency.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
failures=0
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

expect() {
    local label="$1"
    local file="$2"
    local wanted="$3"
    if grep -qxF -- "$wanted" "$file"; then
        printf 'PASS %s\n' "$label"
    else
        printf 'FAIL %s: got %s\n' "$label" "$(cat "$file")"
        failures=$((failures + 1))
    fi
}

apply_twice() {
    local script="$1"
    local file="$2"
    sed -i -E "$script" "$file"
    sed -i -E "$script" "$file"
}

check_hooks() {
    local file="$work_dir/mkinitcpio.conf"
    printf 'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)\n' > "$file"
    apply_twice '/^HOOKS=/ s/ kms([ )])/\1/' "$file"
    expect "kms hook removed" "$file" \
        'HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)'

    printf 'MODULES=()\n' > "$file"
    apply_twice "/^MODULES=/ { /nvidia_drm/! { s/\\)/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/; s/\\( /(/ } }" "$file"
    expect "early nvidia modules" "$file" 'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)'
}

check_cmdlines() {
    local param="nvidia_drm.modeset=1"
    local file="$work_dir/entry.conf"
    printf 'options root=UUID=abc rootflags=subvol=@ rw lsm=landlock,lockdown,yama,integrity,apparmor,bpf\n' > "$file"
    apply_twice "/^options / { / ${param//./\\.}( |\$)/! s/\$/ $param/ }" "$file"
    expect "systemd-boot entry" "$file" \
        "options root=UUID=abc rootflags=subvol=@ rw lsm=landlock,lockdown,yama,integrity,apparmor,bpf $param"

    printf '    cmdline: root=UUID=abc rw\n' > "$file"
    apply_twice "/^[[:space:]]*(kernel_)?cmdline:/ { / ${param//./\\.}( |\$)/! s/\$/ $param/ }" "$file"
    expect "limine cmdline" "$file" "    cmdline: root=UUID=abc rw $param"

    printf 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"\n' > "$file"
    apply_twice "/^GRUB_CMDLINE_LINUX_DEFAULT=/ { / ${param//./\\.}[ \"]/! s/\"\$/ $param\"/ }" "$file"
    expect "grub cmdline" "$file" "GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet $param\""
}

# Вопрос о правке загрузчика должен дойти до терминала. Раньше список записей читался циклом
# `while read ... < <(find)`, цикл занимал stdin, и правка молча пропускалась. Терминал даю через script.
check_boot_prompt() {
    local boot="$work_dir/boot"
    local runner="$work_dir/prompt.sh"
    mkdir -p "$boot/loader/entries"
    printf 'options root=UUID=abc rw\n' > "$boot/loader/entries/arch.conf"
    cat > "$runner" <<RUNNER
source "$repo_dir/lib/ui.sh"
source "$repo_dir/lib/bootloader.sh"
dry_run=0
sudo() { "\$@"; }
bootctl() { if [[ "\$*" == *is-installed* ]]; then return 0; fi; printf '%s\n' "$boot"; }
add_kernel_param "nvidia_drm.modeset=1"
RUNNER
    printf 'yes\n' | script -qec "bash $runner" /dev/null > "$work_dir/prompt.log" 2>&1 || true
    expect "systemd-boot entry patched after a typed yes" "$boot/loader/entries/arch.conf" \
        'options root=UUID=abc rw nvidia_drm.modeset=1'
}

check_hooks
check_cmdlines
check_boot_prompt
if (( failures > 0 )); then
    printf '%d sed checks failed\n' "$failures"
    exit 1
fi
printf 'all sed checks passed\n'
