#!/usr/bin/env bash
# Checks resuming an unfinished --from-iso install with fake system tools: it continues from the saved stage
# and never calls wipefs, sgdisk or mkfs.
# This work made by Anfinogentov Nikita

# Проверки нарочно в одинарных кавычках: их раскрывает eval в check, а не shell при вызове
# shellcheck disable=SC2016

set -uo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
failures=0

check() {
    local label="$1"
    local condition="$2"
    if eval "$condition"; then
        printf 'PASS %s\n' "$label"
    else
        printf 'FAIL %s\n' "$label"
        failures=$((failures + 1))
    fi
}

# Здесь я подменяю все системные программы, которые трогает установка; каждая пишет вызов в журнал
make_fakes() {
    local tool
    mkdir -p "$work_dir/bin"
    for tool in wipefs sgdisk mkfs.fat mkfs.btrfs partprobe udevadm pacman pacstrap rsync mount umount hwclock; do
        printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >> "$FAKE_LOG"\nexit 0\n' "$tool" > "$work_dir/bin/$tool"
    done
    cat > "$work_dir/bin/genfstab" <<'FAKE'
#!/usr/bin/env bash
printf 'genfstab %s\n' "$*" >> "$FAKE_LOG"
printf 'UUID=fake / btrfs rw 0 0\n'
FAKE
    # lsblk как на настоящем NVMe: PKNAME у -p уже с /dev/, первым идёт чужой vfat, ESP — третий раздел
    cat > "$work_dir/bin/lsblk" <<'FAKE'
#!/usr/bin/env bash
printf 'lsblk %s\n' "$*" >> "$FAKE_LOG"
case "$*" in
    "-lnpo NAME,FSTYPE,LABEL,PKNAME") printf '/dev/nvme0n1p2 btrfs arch /dev/nvme0n1\n/dev/sda1 btrfs data /dev/sda\n' ;;
    "-lnpo NAME,PARTTYPE /dev/nvme0n1")
        printf '/dev/nvme0n1p1 ebd0a0a2-b9e5-4433-87c0-68b6b72699c7\n'
        printf '/dev/nvme0n1p2 0fc63daf-8483-4772-8e79-3d69d8477de4\n'
        printf '/dev/nvme0n1p3 C12A7328-F81F-11D2-BA4B-00A0C93EC93B\n' ;;
    *) printf 'nvme0n1 931.5G Fake NVMe 123\n' ;;
esac
FAKE
    # findmnt: /mnt не смонтирован; тип /mnt/boot задаёт FAKE_BOOT_FS
    cat > "$work_dir/bin/findmnt" <<'FAKE'
#!/usr/bin/env bash
if [[ "$*" == *"-no FSTYPE"* ]]; then
    printf '%s\n' "${FAKE_BOOT_FS:-vfat}"
    exit 0
fi
exit 1
FAKE
    cat > "$work_dir/bin/blkid" <<'FAKE'
#!/usr/bin/env bash
printf 'fake-root-uuid\n'
FAKE
    cat > "$work_dir/bin/arch-chroot" <<'FAKE'
#!/usr/bin/env bash
printf 'arch-chroot %s\n' "$*" >> "$FAKE_LOG"
if [[ "$*" == *" id -u "* ]]; then
    exit 1
fi
cat > /dev/null
exit 0
FAKE
    chmod +x "$work_dir/bin/"*
}

make_root() {
    local root="$1"
    mkdir -p "$root/etc/sudoers.d" "$root/boot/loader/entries" "$root/root"
    printf '#en_US.UTF-8 UTF-8\n#ru_RU.UTF-8 UTF-8\n' > "$root/etc/locale.gen"
}

# Сценарий: стадия из файла, данные пользователя уже известны (как после вопросов на образе)
run_resume() {
    local name="$1"
    local stage="$2"
    local root="$work_dir/root-$name"
    make_root "$root"
    printf '%s\n' "$stage" > "$root/.dots-install-stage"
    : > "$work_dir/log-$name"
    env PATH="$work_dir/bin:$PATH" FAKE_LOG="$work_dir/log-$name" \
        bash -c 'source "$1/install.d/05-from-iso.sh"; mount_root="$2"
                 hostname=testhost; user_name=tester; timezone=UTC; password=secret
                 set +e; continue_from_stage /dev/fake2 < /dev/null; printf "RC=%s\n" "$?"' \
        _ "$repo_dir" "$root" > "$work_dir/out-$name" 2>&1
}

# Поиск недоделанной установки целиком, через find_unfinished с поддельными lsblk и mount
run_find() {
    local root="$work_dir/root-find"
    make_root "$root"
    printf 'base\n' > "$root/.dots-install-stage"
    : > "$work_dir/log-find"
    env PATH="$work_dir/bin:$PATH" FAKE_LOG="$work_dir/log-find" \
        bash -c 'source "$1/install.d/05-from-iso.sh"; mount_root="$2"; set +e
                 find_unfinished; printf "RC=%s\nROOT=%s\nEFI=%s\nDISK=%s\nSTAGE=%s\n" "$?" "$resume_root" "$resume_efi" "$resume_disk" "$resume_stage"' \
        _ "$repo_dir" "$root" > "$work_dir/out-find" 2>&1
}

# /mnt/boot не раздел EFI: ни pacstrap, ни загрузчик запускаться не должны
run_no_boot() {
    local root="$work_dir/root-noboot"
    make_root "$root"
    printf 'partitioned\n' > "$root/.dots-install-stage"
    : > "$work_dir/log-noboot"
    env PATH="$work_dir/bin:$PATH" FAKE_LOG="$work_dir/log-noboot" FAKE_BOOT_FS=btrfs \
        bash -c 'source "$1/install.d/05-from-iso.sh"; mount_root="$2"
                 hostname=testhost; user_name=tester; timezone=UTC; password=secret
                 set +e; continue_from_stage /dev/fake2 < /dev/null; printf "RC=%s\n" "$?"' \
        _ "$repo_dir" "$root" > "$work_dir/out-noboot" 2>&1
}

value_of() {
    sed -n "s/^$2=//p" "$work_dir/out-$1"
}

rc_of() {
    sed -n 's/^RC=//p' "$work_dir/out-$1"
}

main() {
    make_fakes
    run_resume from_partitioned partitioned
    run_resume from_configured configured:tester
    run_find
    run_no_boot

    check "find: unfinished install found" '[[ "$(value_of find RC)" == 0 ]]'
    check "find: root partition with full /dev path" '[[ "$(value_of find ROOT)" == /dev/nvme0n1p2 ]]'
    check "find: ESP chosen by partition type, not the first vfat" '[[ "$(value_of find EFI)" == /dev/nvme0n1p3 ]]'
    check "find: disk path is not doubled" '[[ "$(value_of find DISK)" == /dev/nvme0n1 ]] && ! grep -q "/dev//dev" "$work_dir/log-find"'
    check "find: stage read" '[[ "$(value_of find STAGE)" == base ]]'
    check "find: probe mount is read-only" 'grep -q "^mount -o ro,subvol=@ /dev/nvme0n1p2" "$work_dir/log-find"'
    check "find: never formats" '! grep -qE "^(wipefs|sgdisk|mkfs)" "$work_dir/log-find"'
    check "no EFI on /boot: stops with Ooops" '! grep -q "^RC=0" "$work_dir/out-noboot" && grep -q "Ooops.." "$work_dir/out-noboot"'
    check "no EFI on /boot: no pacstrap, no bootloader" '! grep -qE "^pacstrap|bootctl" "$work_dir/log-noboot"'
    check "root account locked" 'grep -q "passwd -l root" "$work_dir/log-from_partitioned"'
    check "inner install knows it runs in chroot" 'grep -q "DOTS_CHROOT=1 bash ./install.sh" "$work_dir/log-from_configured"'

    check "from partitioned: code 0" '[[ "$(rc_of from_partitioned)" == 0 ]]'
    check "from partitioned: never wipes or formats" '! grep -qE "^(wipefs|sgdisk|mkfs)" "$work_dir/log-from_partitioned"'
    check "from partitioned: pacstrap runs" 'grep -q "^pacstrap" "$work_dir/log-from_partitioned"'
    check "from partitioned: user created and dotfiles installed" 'grep -q "useradd" "$work_dir/log-from_partitioned" && grep -q "runuser" "$work_dir/log-from_partitioned"'
    check "from partitioned: fstab written once" '[[ "$(grep -c fake "$work_dir/root-from_partitioned/etc/fstab")" == 1 ]]'
    check "from partitioned: boot entry has AppArmor lsm" 'grep -q "lsm=landlock,lockdown,yama,integrity,apparmor,bpf" "$work_dir/root-from_partitioned/boot/loader/entries/arch.conf"'
    check "from partitioned: stage file removed at the end" '[[ ! -f "$work_dir/root-from_partitioned/.dots-install-stage" ]]'

    check "from configured: code 0" '[[ "$(rc_of from_configured)" == 0 ]]'
    check "from configured: no pacstrap, no formatting" '! grep -qE "^(wipefs|sgdisk|mkfs|pacstrap)" "$work_dir/log-from_configured"'
    check "from configured: only the dotfiles stage runs" 'grep -q "runuser" "$work_dir/log-from_configured" && ! grep -q "useradd" "$work_dir/log-from_configured"'

    if (( failures > 0 )); then
        printf '%d resume checks failed\n' "$failures"
        cat "$work_dir"/out-*
        exit 1
    fi
    printf 'all resume checks passed\n'
}

main
