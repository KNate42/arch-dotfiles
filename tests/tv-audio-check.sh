#!/usr/bin/env bash
# Checks tv-audio with a fake pactl modelling an Nvidia card: one HDMI output per card profile.
# The TV output appears only after switching the profile; unplugging must bring back the old profile and output.
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

# Здесь я описываю карту: порт 0 — монитор DELL (профиль hdmi-stereo), порт 1 — ТВ SAMSUNG (hdmi-stereo-extra1).
# Выход HDMI существует только для активного профиля, как у настоящей карты Nvidia.
make_fakes() {
    mkdir -p "$work_dir/bin" "$work_dir/home"
    printf 'output:hdmi-stereo\n' > "$work_dir/profile"
    printf 'alsa_output.pci-0000_01_00.1.hdmi-stereo\n' > "$work_dir/default"
    cat > "$work_dir/bin/pactl" <<'FAKE'
#!/usr/bin/env bash
profile="$(cat "$FAKE_DIR/profile")"
sinks() {
    local suffix="${profile#output:}"
    local port=hdmi-output-0
    [[ "$suffix" == hdmi-stereo-extra1 ]] && port=hdmi-output-1
    printf '[ { "name": "alsa_output.pci-0000_01_00.1.%s", "description": "GA106 HDMI Audio", "ports": [ { "name": "%s", "availability": "available" } ] },\n' "$suffix" "$port"
    printf '  { "name": "alsa_output.usb-headset.analog-stereo", "description": "USB Headset", "ports": [] } ]\n'
}
case "$*" in
    "-f json list sinks") sinks ;;
    "-f json list cards")
        printf '[ { "name": "alsa_card.pci-0000_01_00.1", "active_profile": "%s", "ports": [\n' "$profile"
        printf '  { "name": "hdmi-output-0", "description": "HDMI / DisplayPort (DELL U2419H)", "availability": "available", "profiles": ["output:hdmi-stereo"] },\n'
        printf '  { "name": "hdmi-output-1", "description": "HDMI / DisplayPort 2 (SAMSUNG)", "availability": "available", "profiles": ["output:hdmi-stereo-extra1"] } ] } ]\n'
        ;;
    "set-card-profile "*) printf '%s\n' "$3" > "$FAKE_DIR/profile" ;;
    "get-default-sink") cat "$FAKE_DIR/default" ;;
    "set-default-sink "*) printf '%s\n' "$2" > "$FAKE_DIR/default" ;;
    "list short sinks") sinks | jq -r '.[] | "0\t\(.name)\tmodule\ts16le\tIDLE"' ;;
    "list short sink-inputs") printf '42\t0\t0\tprotocol-native.c\tfloat32le\n' ;;
    "move-sink-input "*) printf '%s\n' "$*" >> "$FAKE_DIR/moves" ;;
esac
exit 0
FAKE
    cat > "$work_dir/bin/hyprctl" <<'FAKE'
#!/usr/bin/env bash
printf '[{"name":"HDMI-A-1","description":"Samsung Electric Company SAMSUNG 0x01000E00"}]\n'
FAKE
    chmod +x "$work_dir/bin/"*
}

run_tv_audio() {
    env HOME="$work_dir/home" PATH="$work_dir/bin:$PATH" FAKE_DIR="$work_dir" \
        bash "$repo_dir/scripts/.local/bin/tv-audio" "$1" >> "$work_dir/out" 2>&1
}

main() {
    make_fakes
    run_tv_audio on
    check "TV on: card switched to the TV profile" '[[ "$(cat "$work_dir/profile")" == output:hdmi-stereo-extra1 ]]'
    check "TV on: sound goes to the TV output" '[[ "$(cat "$work_dir/default")" == alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1 ]]'
    check "TV on: playing stream moved too" 'grep -q "move-sink-input 42 alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1" "$work_dir/moves"'
    run_tv_audio off
    check "TV off: monitor profile restored" '[[ "$(cat "$work_dir/profile")" == output:hdmi-stereo ]]'
    check "TV off: sound back on the monitor HDMI output" '[[ "$(cat "$work_dir/default")" == alsa_output.pci-0000_01_00.1.hdmi-stereo ]]'

    # ТВ без имени в EDID: звук не трогаю и честно сообщаю
    sed -i 's/(SAMSUNG)/(UNKNOWN)/' "$work_dir/bin/pactl"
    printf 'output:hdmi-stereo\n' > "$work_dir/profile"
    : > "$work_dir/out"
    run_tv_audio on
    check "no TV name: Ooops and nothing switched" 'grep -q "Ooops.." "$work_dir/out" && [[ "$(cat "$work_dir/profile")" == output:hdmi-stereo ]]'

    if (( failures > 0 )); then
        printf '%d tv-audio checks failed\n' "$failures"
        cat "$work_dir/out"
        exit 1
    fi
    printf 'all tv-audio checks passed\n'
}

main
