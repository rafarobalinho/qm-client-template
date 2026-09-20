#!/usr/bin/env bash
set -e

echo "========================================================"
echo "    QM - Ativando Console de Administracao (Admin UI)"
echo "========================================================"

echo "[1/5] Concedendo permissoes org_admin no PostgreSQL..."
docker exec -i qm-hostinger-client-pg psql -U postgres -d qm -c "
INSERT INTO admin_grants (principal_id, scope_id, role)
VALUES
  ('rafael', 'org:hostinger-client', 'org_admin'),
  ('rafaelrobalinho@gmail.com', 'org:hostinger-client', 'org_admin')
ON CONFLICT (principal_id, scope_id, role) DO NOTHING;
"

echo "[2/5] Atualizando configuracao em qm.config.jsonc..."
if grep -q "ADMIN_GRANTS" /opt/qm-app/qm.config.jsonc; then
  sed -i 's/"ADMIN_GRANTS": "[^"]*"/"ADMIN_GRANTS": "rafael:org_admin,rafaelrobalinho@gmail.com:org_admin"/' /opt/qm-app/qm.config.jsonc
fi

echo "[3/5] Instalando bundle da interface Admin..."
curl -fsSL https://raw.githubusercontent.com/rafarobalinho/qm-client-template/main/admin.html -o /opt/qm-app/admin.html
docker cp /opt/qm-app/admin.html qm-hostinger-client-web-ui:/app/dist-web/admin.html

echo "[4/5] Instalando roteador integrado do Web UI..."
curl -fsSL https://raw.githubusercontent.com/rafarobalinho/qm-client-template/main/server_index.ts -o /opt/qm-app/index.ts
docker cp /opt/qm-app/index.ts qm-hostinger-client-web-ui:/app/server/index.ts

echo "[5/5] Reiniciando containers qm-hostinger-client-core e qm-hostinger-client-web-ui..."
docker restart qm-hostinger-client-core qm-hostinger-client-web-ui

echo "Aguardando inicializacao (5 segundos)..."
sleep 5

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/admin/ || echo "err")
echo ""
echo "========================================================"
if [ "$STATUS" = "200" ]; then
  echo "    SUCESSO! Admin console esta respondendo com HTTP 200!"
else
  echo "    HTTP Status retornado: $STATUS"
fi
echo "    Acesse: http://179.198.102.152:9082/admin/"
echo "========================================================"
