#!/usr/bin/env bash
# Security and privacy: nftables firewall, Docker ports on localhost, random Wi-Fi MAC,
# DNS-over-TLS via systemd-resolved, sudo timeout, no core dumps, on-demand scanners, no pkgstats.
# This work made by Anfinogentov Nikita

set -euo pipefail

repo_dir="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# shellcheck source=../lib/ui.sh
source "$repo_dir/lib/ui.sh"
parse_flags "$@"

# DNS для DNS-over-TLS: «адрес#имя для TLS». Сменить сервер — поменять только эту строку.
# Quad9: блокирует известные вредоносные домены и не хранит IP (dns.quad9.net)
dns_servers="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net"
sudo_timeout_minutes=5

security_packages=(nftables clamav rkhunter lynis)

install_packages() {
    local missing=()
    local pkg
    for pkg in "${security_packages[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done
    if (( ${#missing[@]} == 0 )); then
        good "nftables и сканеры уже стоят"
        return 0
    fi
    run_cmd sudo pacman -S --needed --noconfirm "${missing[@]}"
}

enable_unit() {
    local unit="$1"
    if systemctl is-enabled -q "$unit" 2>/dev/null; then
        good "$unit уже включена"
    else
        run_cmd sudo systemctl enable "$unit"
    fi
}

# Здесь я не делаю flush ruleset, как в стандартном /etc/nftables.conf: он стёр бы правила Docker.
# Своя таблица пересоздаётся целиком, цепочки forward нет — её ведёт Docker для контейнеров.
nftables_config() {
    cat <<'NFT'
#!/usr/bin/nft -f
# Firewall of arch-dotfiles: incoming traffic is dropped, outgoing is allowed.
# This work made by Anfinogentov Nikita

destroy table inet dots_firewall

table inet dots_firewall {
    chain input {
        type filter hook input priority filter; policy drop;

        ct state invalid drop
        ct state { established, related } accept
        iif "lo" accept

        meta l4proto icmp accept
        meta l4proto ipv6-icmp accept

        # Ответы DHCPv6-сервера приходят на порт 546 без установленного соединения
        udp sport 547 udp dport 546 accept
    }
}
NFT
}

setup_firewall() {
    if [[ -f /etc/nftables.conf ]] && ! grep -q 'dots_firewall' /etc/nftables.conf && [[ ! -f /etc/nftables.conf.orig ]]; then
        run_cmd sudo cp -a /etc/nftables.conf /etc/nftables.conf.orig
    fi
    write_file_root /etc/nftables.conf "$(nftables_config)"
    if [[ "$dry_run" == 0 ]]; then
        # Здесь я откладываю проверку на новом ядре: nft -c тоже обращается к модулям работающего ядра.
        if in_chroot || [[ ! -f "/usr/lib/modules/$(uname -r)/modules.dep" ]]; then
            warn "модули работающего ядра недоступны или это chroot; проверка nftables отложена до перезагрузки"
            warn "после перезагрузки проверьте: sudo nft -c -f /etc/nftables.conf && systemctl status nftables.service"
        elif ! sudo nft -c -f /etc/nftables.conf; then
            oops "nft не принял /etc/nftables.conf"
            return 1
        fi
    fi
    enable_unit nftables.service
}

# Здесь я привязываю опубликованные порты Docker к 127.0.0.1: `-p 8080:80` больше не открывает порт в сеть.
# "ip" действует на стандартную сеть, default-network-opts — на новые сети, в том числе сети Compose.
# Открыть наружу можно только явно: `-p 0.0.0.0:8080:80`. Чужой daemon.json не затираю, а дополняю через jq.
docker_json="/etc/docker/daemon.json"
docker_filter='.ip = "127.0.0.1" | .["default-network-opts"].bridge["com.docker.network.bridge.host_binding_ipv4"] = "127.0.0.1"'

setup_docker_ports() {
    local current="{}"
    local merged
    if [[ "$dry_run" == 1 ]]; then
        say "[dry-run] дополнил бы $docker_json: ip и default-network-opts = 127.0.0.1"
        return 0
    fi
    if [[ -f "$docker_json" ]]; then
        # Файл бывает доступен только root, поэтому читаю через sudo
        if ! current="$(sudo cat "$docker_json" | jq -e .)"; then
            oops "$docker_json — не JSON; исправьте его вручную и запустите шаг снова"
            return 1
        fi
    fi
    if ! merged="$(jq -e "$docker_filter" <<< "$current")"; then
        oops "не смог дополнить настройки Docker"
        return 1
    fi
    if [[ "$current" == "$merged" ]]; then
        good "порты Docker по умолчанию только на 127.0.0.1"
        warn_existing_networks
        return 0
    fi
    if [[ -f "$docker_json" && ! -f "$docker_json.orig" ]]; then
        run_cmd sudo cp -a "$docker_json" "$docker_json.orig"
    fi
    write_file_root "$docker_json" "$merged"
    if [[ "$dry_run" == 0 ]] && systemctl is-active -q docker.service 2>/dev/null; then
        warn "Docker уже запущен: новые настройки заработают после sudo systemctl restart docker"
    fi
    warn_existing_networks
}

# Уже созданные сети (например, от docker compose up) живут со старыми настройками до пересоздания
warn_existing_networks() {
    local networks
    if [[ "$dry_run" == 1 ]] || ! docker info >/dev/null 2>&1; then
        return 0
    fi
    if ! networks="$(docker network ls --filter driver=bridge --format '{{.Name}}' | sed '/^bridge$/d')"; then
        warn "не смог проверить существующие сети Docker: проверьте docker network ls"
        return 0
    fi
    if [[ -n "$networks" ]]; then
        warn "эти сети Docker созданы раньше и публикуют порты на все адреса, пока их не пересоздать (docker compose down && up): $(tr '\n' ' ' <<< "$networks")"
    fi
}

setup_mac_randomization() {
    write_file_root /etc/NetworkManager/conf.d/20-mac-randomization.conf "$(printf '%s\n' \
        '# Random MAC while scanning Wi-Fi, a stable per-network MAC when connected (Arch Wiki: NetworkManager)' \
        '[device-mac-randomization]' \
        'wifi.scan-rand-mac-address=yes' \
        '' \
        '[connection-mac-randomization]' \
        'wifi.cloned-mac-address=stable')"
}

# DNS-over-TLS строгий (yes): если TLS не получился, запрос не уходит открытым текстом.
# NetworkManager перестаёт раздавать DNS от роутера (dns=none), иначе запросы шли бы и туда без шифрования.
setup_dns() {
    enable_unit systemd-timesyncd.service
    enable_unit systemd-resolved.service
    if [[ "$dry_run" == 0 ]] && ! in_chroot && ! systemd-detect-virt --container >/dev/null 2>&1; then
        # Здесь я запускаю синхронизацию времени до проверки сертификата DNS-сервера.
        run_cmd sudo systemctl start systemd-timesyncd.service
    fi
    write_file_root /etc/systemd/resolved.conf.d/20-dns-over-tls.conf "$(printf '%s\n' \
        '[Resolve]' \
        "DNS=$dns_servers" \
        'DNSOverTLS=yes' \
        'DNSSEC=allow-downgrade' \
        'Domains=~.' \
        'FallbackDNS=')"
    write_file_root /etc/NetworkManager/conf.d/30-dns.conf "$(printf '%s\n' '[main]' 'dns=none' 'systemd-resolved=false')"
    if [[ "$dry_run" == 0 ]] && { in_chroot || systemd-detect-virt --container >/dev/null 2>&1; }; then
        # Здесь я сохраняю строгий DoT: проверить его смогу после первой загрузки системы.
        warn "это chroot или контейнер: DNSOverTLS=yes сохранён; проверка строгого DoT отложена до первой загрузки"
        warn "после первой загрузки проверьте: timeout 30s resolvectl query --cache=no archlinux.org"
        return 0
    fi
    if [[ "$dry_run" == 0 ]] && systemctl is-active -q NetworkManager.service; then
        run_cmd sudo systemctl reload NetworkManager.service
    fi
    # Здесь я перечитываю конфиг и при уже правильной ссылке resolv.conf.
    run_cmd sudo systemctl restart systemd-resolved.service
    link_resolv_conf
    if [[ "$dry_run" == 1 ]]; then
        say "[dry-run] проверил бы строгий DoT: timeout 30s resolvectl query --cache=no archlinux.org"
        return 0
    fi
    if timeout 30s resolvectl query --cache=no archlinux.org; then
        good "строгий DNS-over-TLS работает"
        return 0
    fi
    # Здесь я предупреждаю о сбое DNS, сохраняя строгий DoT и продолжая установку служб.
    warn "ВНИМАНИЕ: строгий DoT не разрешил archlinux.org за 30 секунд; DNS сейчас может не работать! DNSOverTLS=yes сохранён"
    warn "частые причины: неверные часы или провайдер блокирует TCP 853; проверьте timedatectl status и resolvectl status"
    warn "повторить проверку: timeout 30s resolvectl query --cache=no archlinux.org"
    warn "ослабить защиту DNS вручную (разрешить незашифрованный DNS): dots-recover dns"
    warn "до шага 55-stow или если команда не найдена: ~/arch-dotfiles/scripts/.local/bin/dots-recover dns"
    return 0
}

link_resolv_conf() {
    local stub="/run/systemd/resolve/stub-resolv.conf"
    if [[ "$(readlink /etc/resolv.conf 2>/dev/null)" == "$stub" ]]; then
        good "/etc/resolv.conf уже ведёт на systemd-resolved"
        return 0
    fi
    # В контейнере resolved не работает: ссылка оборвала бы интернет, пропускаю
    if systemd-detect-virt --container >/dev/null 2>&1; then
        warn "это контейнер: /etc/resolv.conf не трогаю"
        return 0
    fi
    # В arch-chroot файл занят точкой монтирования; ссылку поставит 05-from-iso после выхода из chroot
    if in_chroot; then
        say "это chroot: ссылку /etc/resolv.conf поставит установщик с образа"
        return 0
    fi
    run_cmd sudo ln -sf "$stub" /etc/resolv.conf
}

setup_sudo_timeout() {
    local target="/etc/sudoers.d/30-timeout"
    local content="Defaults timestamp_timeout=$sudo_timeout_minutes"
    if [[ "$dry_run" == 1 ]]; then
        printf '\033[2m[dry-run]\033[0m проверил бы и при нужде записал %s: %s\n' "$target" "$content"
        return 0
    fi
    if [[ "$(sudo -n cat "$target" 2>/dev/null)" == "$content" ]]; then
        good "sudo спрашивает пароль снова через $sudo_timeout_minutes мин"
        return 0
    fi
    local draft
    draft="$(mktemp)"
    printf '%s\n' "$content" > "$draft"
    # Здесь я проверяю файл через visudo до установки: ошибка в sudoers может отнять sudo совсем
    if ! sudo visudo -cf "$draft" >/dev/null; then
        oops "visudo не принял $content"
        rm -f "$draft"
        return 1
    fi
    if ! sudo install -m 440 -o root -g root "$draft" "$target"; then
        oops "не смог установить $target"
        rm -f "$draft"
        return 1
    fi
    rm -f "$draft"
}

disable_core_dumps() {
    write_file_root /etc/systemd/coredump.conf.d/20-disable.conf "$(printf '%s\n' '[Coredump]' 'Storage=none' 'ProcessSizeMax=0')"
}

# freshclam раз в сутки по таймеру (обновить базы и выйти); демоны clamav и rkhunter не включаю
setup_scanners() {
    enable_unit clamav-freshclam-once.timer
}

check_pkgstats() {
    if pacman -Qq pkgstats >/dev/null 2>&1; then
        warn "стоит pkgstats (отправляет список пакетов на сервер Arch); удалить: sudo pacman -Rns pkgstats"
    else
        good "pkgstats не установлен"
    fi
}

main() {
    install_packages
    setup_firewall
    if command -v docker >/dev/null 2>&1 || [[ "$dry_run" == 1 ]]; then
        setup_docker_ports
    fi
    setup_mac_randomization
    setup_dns
    setup_sudo_timeout
    disable_core_dumps
    setup_scanners
    check_pkgstats
}

main
