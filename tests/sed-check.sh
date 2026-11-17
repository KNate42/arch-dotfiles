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
    # Пустой каталог пресетов: без него тест увидел бы UKI самой машины и пошёл бы не той веткой
    mkdir -p "$work_dir/no-presets"
    cat > "$runner" <<RUNNER
export DOTS_PRESET_DIR="$work_dir/no-presets"
source "$repo_dir/lib/ui.sh"
source "$repo_dir/lib/bootloader.sh"
dry_run=0
sudo() { "\$@"; }
bootctl() { if [[ "\$*" == *is-installed* ]]; then return 0; fi; printf '%s\n' "$boot"; }
add_kernel_param "nvidia_drm.modeset=1"
RUNNER
    # Здесь я отвечаю, как человек, только после появления вопроса: набранное заранее ui.sh выбрасывает
    local log="$work_dir/prompt.log"
    : > "$log"
    { for _ in $(seq 1 100); do grep -q 'y/N' "$log" && break; sleep 0.1; done; sleep 0.3; printf 'yes\n'; } \
        | script -qec "bash $runner" /dev/null > "$log" 2>&1 || true
    expect "systemd-boot entry patched after a typed yes" "$boot/loader/entries/arch.conf" \
        'options root=UUID=abc rw nvidia_drm.modeset=1'
}

# /etc/kernel/cmdline для UKI: дописать параметр, заменить чужой lsm=, второй прогон ничего не меняет
check_uki_cmdline() {
    local file="$work_dir/cmdline"
    local lsm="lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
    (
        failures=0
        source "$repo_dir/lib/ui.sh"
        source "$repo_dir/lib/bootloader.sh"
        printf 'root=PARTUUID=abc rootflags=subvol=@ rw rootfstype=btrfs\n' > "$file"
        apply_twice "$(uki_cmdline_sed "$lsm")" "$file"
        expect "uki cmdline append" "$file" "root=PARTUUID=abc rootflags=subvol=@ rw rootfstype=btrfs $lsm"

        printf 'root=PARTUUID=abc lsm=landlock,lockdown,yama,integrity,bpf rw\n' > "$file"
        apply_twice "$(uki_cmdline_sed "$lsm")" "$file"
        expect "uki cmdline replaces old lsm=" "$file" "root=PARTUUID=abc $lsm rw"

        printf 'root=PARTUUID=abc rw\n' > "$file"
        apply_twice "$(uki_cmdline_sed nvidia_drm.modeset=1)" "$file"
        expect "uki cmdline dotted key" "$file" "root=PARTUUID=abc rw nvidia_drm.modeset=1"
        exit "$failures"
    ) || failures=$((failures + $?))
}

# Полный путь UKI под терминалом: правка cmdline после «yes» и пересборка через mkinitcpio -P
check_uki_prompt() {
    local runner="$work_dir/uki.sh"
    local log="$work_dir/uki.log"
    mkdir -p "$work_dir/uki/presets"
    printf 'root=PARTUUID=abc rw\n' > "$work_dir/uki/cmdline"
    printf 'PRESETS=(default)\ndefault_uki="/boot/EFI/Linux/arch-linux.efi"\n' > "$work_dir/uki/presets/linux.preset"
    cat > "$runner" <<RUNNER
export DOTS_KERNEL_CMDLINE="$work_dir/uki/cmdline" DOTS_PRESET_DIR="$work_dir/uki/presets"
source "$repo_dir/lib/ui.sh"
source "$repo_dir/lib/bootloader.sh"
dry_run=0
sudo() { "\$@"; }
bootctl() { return 1; }
mkinitcpio() { touch "$work_dir/uki/rebuilt"; }
add_kernel_param "lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
RUNNER
    : > "$log"
    { for _ in $(seq 1 100); do grep -q 'yes' "$log" && break; sleep 0.1; done; sleep 0.3; printf 'yes\n'; } \
        | script -qec "bash $runner" /dev/null > "$log" 2>&1 || true
    expect "uki cmdline patched after a typed yes" "$work_dir/uki/cmdline" \
        'root=PARTUUID=abc rw lsm=landlock,lockdown,yama,integrity,apparmor,bpf'
    if [[ -f "$work_dir/uki/rebuilt" ]]; then
        printf 'PASS uki rebuilt with mkinitcpio -P\n'
    else
        printf 'FAIL uki was not rebuilt\n'
        failures=$((failures + 1))
    fi
}

check_hooks
check_cmdlines
check_boot_prompt
check_uki_cmdline
check_uki_prompt
if (( failures > 0 )); then
    printf '%d sed checks failed\n' "$failures"
    exit 1
fi
printf 'all sed checks passed\n'
