#!/usr/bin/env bash
# Instala qm-firewall.sh + unidade systemd no servidor (rode como root, no VPS).
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
install -m 755 "$DIR/qm-firewall.sh" /usr/local/sbin/qm-firewall.sh
install -m 644 "$DIR/qm-firewall.service" /etc/systemd/system/qm-firewall.service
systemctl daemon-reload
systemctl enable --now qm-firewall.service
iptables -S DOCKER-USER
