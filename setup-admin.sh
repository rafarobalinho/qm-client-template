#!/usr/bin/env bash
# Ativa o console de administracao (Admin UI) numa instancia QM ja implantada
# com o alvo docker, e concede org_admin ao e-mail do administrador.
#
# Uso (no servidor onde os containers rodam):
#   ADMIN_EMAIL=voce@empresa.com bash setup-admin.sh
#
# Variaveis opcionais:
#   ADMIN_EMAIL   e-mail do administrador   (padrao: rafaelrobalinho@gmail.com)
#   QM_DIR        diretorio do deployment    (padrao: /opt/qm-app)
#   ORG_ID        orgId do deployment        (padrao: lido de qm.config.jsonc)
#   TEMPLATE_REF  commit do template de onde baixar admin.html e o roteador
set -euo pipefail

ADMIN_EMAIL="$(echo "${ADMIN_EMAIL:-rafaelrobalinho@gmail.com}" | tr '[:upper:]' '[:lower:]')"
QM_DIR="${QM_DIR:-/opt/qm-app}"
TEMPLATE_REF="${TEMPLATE_REF:-104d9d6}"
RAW="https://raw.githubusercontent.com/rafarobalinho/qm-client-template/${TEMPLATE_REF}"

cd "$QM_DIR"
ORG_ID="${ORG_ID:-$(npm exec qm -- config get orgId)}"
PREFIX="qm-${ORG_ID}"
WEB_PORT="$(docker port "${PREFIX}-web-ui" 8080 2>/dev/null | head -1 | sed 's/.*://')"
WEB_PORT="${WEB_PORT:-8080}"

echo "========================================================"
echo "    QM - Ativando Console de Administracao (Admin UI)"
echo "    org: ${ORG_ID}   admin: ${ADMIN_EMAIL}"
echo "========================================================"

echo "[1/6] Gravando ADMIN_GRANTS no .env do deployment..."
npm exec qm -- secrets set ADMIN_GRANTS "${ADMIN_EMAIL}:org_admin"

echo "[2/6] Declarando secretEnv.core.ADMIN_GRANTS e env.web-ui.ADMIN_PRINCIPAL em qm.config.jsonc..."
ADMIN_EMAIL="$ADMIN_EMAIL" node - <<'NODE'
const fs = require("fs");
const file = "qm.config.jsonc";
let s = fs.readFileSync(file, "utf8");
const email = process.env.ADMIN_EMAIL;
const addProp = (text, key, value) => {
  // Insere `"key": value` como ultima propriedade do objeto raiz (JSON com comentarios).
  const end = text.lastIndexOf("}");
  let head = text.slice(0, end).replace(/\s+$/, "");
  if (!/[{,]$/.test(head)) head += ",";
  return `${head}\n  "${key}": ${value}\n}\n`;
};
if (/"ADMIN_PRINCIPAL"\s*:/.test(s)) {
  s = s.replace(/"ADMIN_PRINCIPAL"\s*:\s*"[^"]*"/, `"ADMIN_PRINCIPAL": "${email}"`);
} else if (/"web-ui"\s*:\s*\{/.test(s)) {
  s = s.replace(/"web-ui"\s*:\s*\{/, `"web-ui": { "ADMIN_PRINCIPAL": "${email}", `);
} else if (/"env"\s*:\s*\{/.test(s)) {
  s = s.replace(/"env"\s*:\s*\{/, `"env": { "web-ui": { "ADMIN_PRINCIPAL": "${email}" }, `);
} else {
  s = addProp(s, "env", `{ "web-ui": { "ADMIN_PRINCIPAL": "${email}" } }`);
}
// ADMIN_GRANTS e segredo: sai de env.core (texto puro na config) e passa a vir do .env via secretEnv.
s = s.replace(/"ADMIN_GRANTS"\s*:\s*"(?!ADMIN_GRANTS")[^"]*"\s*,?\s*/g, "").replace(/,(\s*})/g, "$1");
if (!/"ADMIN_GRANTS"\s*:\s*"ADMIN_GRANTS"/.test(s)) {
  if (/"secretEnv"\s*:\s*\{\s*"core"\s*:\s*\{/.test(s)) {
    s = s.replace(/"secretEnv"\s*:\s*\{\s*"core"\s*:\s*\{/, `"secretEnv": { "core": { "ADMIN_GRANTS": "ADMIN_GRANTS", `);
  } else if (/"secretEnv"\s*:\s*\{/.test(s)) {
    s = s.replace(/"secretEnv"\s*:\s*\{/, `"secretEnv": { "core": { "ADMIN_GRANTS": "ADMIN_GRANTS" }, `);
  } else {
    s = addProp(s, "secretEnv", `{ "core": { "ADMIN_GRANTS": "ADMIN_GRANTS" } }`);
  }
}
fs.writeFileSync(file, s);
NODE
npm exec qm -- check

echo "[3/6] Recriando os containers com o novo ambiente (docker restart nao aplica variaveis novas)..."
npm exec qm -- up

echo "[4/6] Concedendo org_admin no PostgreSQL (efeito imediato; core tambem semeia a partir de ADMIN_GRANTS)..."
docker exec -i "${PREFIX}-pg" psql -U postgres -d qm -v ON_ERROR_STOP=1 -c "
INSERT INTO admin_grants (principal_id, scope_id, role)
VALUES ('${ADMIN_EMAIL}', 'org:${ORG_ID}', 'org_admin')
ON CONFLICT (principal_id, scope_id, role) DO NOTHING;
"

echo "[5/6] Instalando o bundle do Admin e o roteador integrado no web-ui..."
curl -fsSL "${RAW}/admin.html" -o "${QM_DIR}/admin.html"
curl -fsSL "${RAW}/server_index.ts" -o "${QM_DIR}/index.ts"
docker cp "${QM_DIR}/admin.html" "${PREFIX}-web-ui:/app/dist-web/admin.html"
docker cp "${QM_DIR}/index.ts" "${PREFIX}-web-ui:/app/server/index.ts"
docker restart "${PREFIX}-web-ui"

echo "[6/6] Verificando..."
sleep 5
STATUS="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${WEB_PORT}/admin/" || echo err)"
ME="$(curl -s "http://localhost:${WEB_PORT}/admin/api/me" || true)"
# /admin/api/sessions e retransmitido ao core com x-admin-actor: prova que o core aceita o e-mail como org_admin.
CORE_STATUS="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${WEB_PORT}/admin/api/sessions" || echo err)"
echo ""
echo "========================================================"
if [ "$STATUS" = "200" ] && echo "$ME" | grep -q "\"principal\":\"${ADMIN_EMAIL}\"" && [ "$CORE_STATUS" = "200" ]; then
  echo "    SUCESSO! /admin/ responde 200 e o core aceita ${ADMIN_EMAIL} como org_admin"
else
  echo "    ATENCAO: /admin/ => HTTP ${STATUS}; /admin/api/me => ${ME}"
  echo "             core via /admin/api/sessions => HTTP ${CORE_STATUS} (esperado 200)"
  echo "             logs: npm exec qm -- logs core --tail 50"
fi
echo "    Acesse: $(npm exec qm -- config get publicUrl)/admin/"
echo "========================================================"
