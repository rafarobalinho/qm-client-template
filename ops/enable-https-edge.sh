#!/usr/bin/env bash
# Publica o portal do QM em HTTPS atraves de um Traefik ja existente no host
# (network_mode=host, provider docker, certresolver Let's Encrypt), e sobe a stack.
# O broker de login (auth) exige HTTPS em producao, por isso este passo e obrigatorio.
#
# Uso (como root, no VPS):
#   DOMAIN=qm.suaempresa.com.br bash ops/enable-https-edge.sh
#   Sem DOMAIN, usa um hostname temporario <ip com hifens>.sslip.io (aponta para este IP).
#
# Variaveis opcionais:
#   QM_DIR         diretorio do deployment            (padrao: /opt/qm-app)
#   CERT_RESOLVER  nome do certresolver no Traefik     (padrao: letsencrypt)
#   ENTRYPOINT     entrypoint TLS do Traefik           (padrao: websecure)
set -euo pipefail

QM_DIR="${QM_DIR:-/opt/qm-app}"
CERT_RESOLVER="${CERT_RESOLVER:-letsencrypt}"
ENTRYPOINT="${ENTRYPOINT:-websecure}"
cd "$QM_DIR"

ORG_ID="$(npm exec qm -- config get orgId)"
BASE_PORT="$(npm exec qm -- config get basePort 2>/dev/null || echo 8080)"
PORTAL_PORT=$((BASE_PORT + 1))
PUBLIC_IP="$(curl -4 -s -m 5 https://api.ipify.org || hostname -I | awk '{print $1}')"
DOMAIN="${DOMAIN:-qm-$(echo "$PUBLIC_IP" | tr . -).sslip.io}"
EDGE="qm-${ORG_ID}-edge"

echo "== org ${ORG_ID}  portal 127.0.0.1:${PORTAL_PORT}  dominio https://${DOMAIN}"

echo "[1/4] Container 'edge' com labels do Traefik (host network => Traefik roteia para 127.0.0.1:${PORTAL_PORT})"
docker rm -f "$EDGE" >/dev/null 2>&1 || true
docker run -d --name "$EDGE" --network host --restart unless-stopped \
  --label traefik.enable=true \
  --label "traefik.http.routers.${EDGE}.rule=Host(\`${DOMAIN}\`)" \
  --label "traefik.http.routers.${EDGE}.entrypoints=${ENTRYPOINT}" \
  --label "traefik.http.routers.${EDGE}.tls.certresolver=${CERT_RESOLVER}" \
  --label "traefik.http.services.${EDGE}.loadbalancer.server.port=${PORTAL_PORT}" \
  alpine:3.20 sleep infinity >/dev/null

echo "[2/4] publicUrl -> https://${DOMAIN}"
DOMAIN="$DOMAIN" node - <<'NODE'
const fs = require("fs");
let s = fs.readFileSync("qm.config.jsonc", "utf8");
s = s.replace(/"publicUrl":\s*"[^"]*"/, `"publicUrl": "https://${process.env.DOMAIN}"`);
fs.writeFileSync("qm.config.jsonc", s);
NODE
npm exec qm -- check

echo "[3/4] Subindo a stack (core, web-ui, admin, auth, portal)"
npm exec qm -- up

echo "[4/4] Verificando (o certificado pode levar ate 1 minuto na primeira emissao)"
for i in $(seq 1 12); do
  CODE="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "https://${DOMAIN}/" || true)"
  [ "$CODE" = "200" ] && break
  sleep 5
done
echo "https://${DOMAIN}/ => HTTP ${CODE:-err}"
docker ps --format '{{.Names}}\t{{.Status}}' | grep -E "qm-${ORG_ID}-"
echo
echo "Portal: https://${DOMAIN}/    Admin: https://${DOMAIN}/admin"
echo "Agora bloqueie as portas diretas: PORTS=\"${BASE_PORT} $((BASE_PORT+1)) $((BASE_PORT+2)) $((BASE_PORT+3))\" bash ops/install-firewall.sh"
