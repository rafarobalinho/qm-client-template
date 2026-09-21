#!/usr/bin/env bash
# Bloqueia, na cadeia DOCKER-USER (a unica que o Docker respeita; ufw/INPUT nao
# alcancam portas publicadas com -p), o acesso externo as portas do QM que nao
# devem ser publicas. Idempotente; instale com ops/install-firewall.sh.
#   IFACE  interface publica            (padrao: eth0)
#   PORTS  portas a bloquear de fora    (padrao: 9080 9082 9083 = core, web-ui e admin; so o portal 9081 fica publico)
set -e
IFACE="${IFACE:-eth0}"
PORTS="${PORTS:-9080 9082 9083}"
for bin in iptables ip6tables; do
  for p in $PORTS; do
    rule=(DOCKER-USER -i "$IFACE" -p tcp -m conntrack --ctorigdstport "$p" -j DROP)
    "$bin" -C "${rule[@]}" 2>/dev/null || "$bin" -I "${rule[@]}"
  done
done
