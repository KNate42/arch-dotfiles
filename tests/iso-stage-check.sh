#!/usr/bin/env bash
# Checks run_user_stage from 05-from-iso.sh with fake rsync and arch-chroot: every failure must stop it with "Ooops..".
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

# Здесь я подменяю rsync и arch-chroot: их поведение задаёт переменная FAKE_MODE, вызовы пишутся в журнал
make_fakes() {
    mkdir -p "$work_dir/bin"
    cat > "$work_dir/bin/rsync" <<'FAKE'
#!/usr/bin/env bash
printf 'rsync %s\n' "$*" >> "$FAKE_LOG"
[[ "$FAKE_MODE" == rsync_fails ]] && exit 23
exit 0
FAKE
    cat > "$work_dir/bin/arch-chroot" <<'FAKE'
#!/usr/bin/env bash
printf 'arch-chroot %s\n' "$*" >> "$FAKE_LOG"
if [[ "$FAKE_MODE" == chown_fails && "$*" == *chown* ]]; then
    exit 1
fi
if [[ "$FAKE_MODE" == install_fails && "$*" == *runuser* ]]; then
    exit 5
fi
exit 0
FAKE
    chmod +x "$work_dir/bin/rsync" "$work_dir/bin/arch-chroot"
}

# Каждый сценарий — в отдельном процессе: файл модуля включает set -e и ловушку EXIT
run_scenario() {
    local mode="$1"
    local root="$work_dir/root-$mode"
    mkdir -p "$root/etc/sudoers.d" "$root/root"
    printf 'configured:tester\n' > "$root/.dots-install-stage"
    : > "$work_dir/log-$mode"
    env PATH="$work_dir/bin:$PATH" FAKE_MODE="$mode" FAKE_LOG="$work_dir/log-$mode" \
        bash -c 'source "$1/install.d/05-from-iso.sh"; mount_root="$2"; set +e; run_user_stage tester; printf "RC=%s\n" "$?"' \
        _ "$repo_dir" "$root" > "$work_dir/out-$mode" 2>&1
}

rc_of() {
    sed -n 's/^RC=//p' "$work_dir/out-$1"
}

main() {
    make_fakes
    local mode
    for mode in rsync_fails chown_fails install_fails ok; do
        run_scenario "$mode"
    done

    check "rsync fails: non-zero code" '[[ "$(rc_of rsync_fails)" != 0 ]]'
    check "rsync fails: Ooops message" 'grep -q "Ooops.." "$work_dir/out-rsync_fails"'
    check "rsync fails: arch-chroot never called" '! grep -q arch-chroot "$work_dir/log-rsync_fails"'
    check "rsync fails: no success message" '! grep -q "установлены" "$work_dir/out-rsync_fails"'

    check "chown fails: non-zero code" '[[ "$(rc_of chown_fails)" != 0 ]]'
    check "chown fails: install not started" '! grep -q runuser "$work_dir/log-chown_fails"'
    check "chown fails: no NOPASSWD file left" '[[ ! -e "$work_dir/root-chown_fails/etc/sudoers.d/99-dots-install" ]]'

    check "install fails: code passed through (5)" '[[ "$(rc_of install_fails)" == 5 ]]'
    check "install fails: Ooops message" 'grep -q "Ooops.." "$work_dir/out-install_fails"'
    check "install fails: NOPASSWD file removed" '[[ ! -e "$work_dir/root-install_fails/etc/sudoers.d/99-dots-install" ]]'
    check "install fails: resume marker kept" '[[ -f "$work_dir/root-install_fails/.dots-install-stage" ]]'

    check "all ok: code 0" '[[ "$(rc_of ok)" == 0 ]]'
    check "all ok: NOPASSWD file removed" '[[ ! -e "$work_dir/root-ok/etc/sudoers.d/99-dots-install" ]]'
    check "all ok: resume marker removed" '[[ ! -f "$work_dir/root-ok/.dots-install-stage" ]]'

    if (( failures > 0 )); then
        printf '%d iso stage checks failed\n' "$failures"
        for mode in rsync_fails chown_fails install_fails ok; do
            printf -- '--- %s\n' "$mode"
            cat "$work_dir/out-$mode"
        done
        exit 1
    fi
    printf 'all iso stage checks passed\n'
}

main
