#!/usr/bin/env bash
# Instala qm-firewall.sh + unidade systemd no servidor (rode como root, no VPS).
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
install -m 755 "$DIR/qm-firewall.sh" /usr/local/sbin/qm-firewall.sh
install -m 644 "$DIR/qm-firewall.service" /etc/systemd/system/qm-firewall.service
if [ -n "${PORTS:-}" ]; then
  mkdir -p /etc/systemd/system/qm-firewall.service.d
  printf '[Service]
Environment="PORTS=%s"
' "$PORTS" > /etc/systemd/system/qm-firewall.service.d/ports.conf
fi
systemctl daemon-reload
systemctl enable qm-firewall.service >/dev/null
systemctl restart qm-firewall.service
iptables -S DOCKER-USER
