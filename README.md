# Template de Deployment QM (Repositório Leve por Cliente)

Este repositório é o **modelo base (template)** para implantar instâncias do **QM (Multiplayer Agent Harness)** personalizadas para diferentes clientes.

Ele segue a arquitetura oficial de **Deployment Layer**, mantendo o código de infraestrutura do QM isolado e expondo apenas as configurações, regras de negócio e ferramentas específicas de cada cliente.

---

## Estrutura do Repositório

```text
├── qm.config.jsonc          # Configuração principal (nome do bot, modelo LLM, serviços ativos)
├── package.json             # Dependência com a versão estável do @yc-software/qm
├── .env.example             # Lista descritiva dos segredos exigidos
├── .env                     # Suas chaves locais (Anthropic/OpenAI, tokens) - NÃO comitar!
├── sandbox/
│   ├── skills/              # Habilidades e instruções personalizadas do cliente
│   │   ├── atendimento-suporte/  # Exemplo de regra operacional em português
│   │   └── greet/                # Exemplo padrão do QM
│   └── tools/               # Ferramentas e scripts CLI executáveis pelos agentes
│       └── example-tool/
├── slack-app-manifest.yml   # Manifesto para criar o bot no Slack da empresa em 1 clique
└── deployment.md            # Manual técnico de operação e deploy
```

---

## Como Criar um Novo Cliente a Partir Deste Template

### Passo 1: Criar o Repositório do Cliente
1. Crie um novo repositório no seu GitHub (ex: `cliente-acme-qm`).
2. Copie os arquivos deste template para o novo repositório.
3. Ajuste o nome em `package.json` (ex: `"name": "cliente-acme-qm"`).

### Passo 2: Configurar o Cliente em `qm.config.jsonc`
Abra `qm.config.jsonc` e ajuste:
```jsonc
{
  "orgId": "cliente-acme",               // Identificador do cliente
  "botName": "Assistente Acme",           // Nome do bot visível aos colaboradores
  "orgName": "Acme Corp",                 // Nome da empresa
  "target": "docker",                     // "docker" (local), "aws" ou "fly"
  "modelProvider": "anthropic",           // "anthropic", "openai" ou "openrouter"
  "services": ["core", "web-ui"]          // Serviços ativos (adicione "slack" se for usar)
}
```

### Passo 3: Configurar os Segredos (`.env`)
1. Copie o arquivo `.env.example` para `.env`:
   ```bash
   cp .env.example .env
   ```
2. Adicione sua chave de API (ex: `ANTHROPIC_API_KEY=sk-ant-...` ou `OPENAI_API_KEY=sk-...`).
3. *(Opcional)* Se for integrar com Slack, configure `SLACK_BOT_TOKEN` e `SLACK_SIGNING_SECRET`.

### Passo 4: Adicionar Regras de Negócio do Cliente (`sandbox/skills/`)
Crie pastas dentro de `sandbox/skills/` com arquivos `SKILL.md`. Cada skill ensina os agentes como agir para determinado departamento da empresa:
- `sandbox/skills/politica-vendas/SKILL.md`
- `sandbox/skills/triagem-financeira/SKILL.md`

### Passo 5: Validar e Subir
1. Instale as dependências:
   ```bash
   npm install
   ```
2. Valide a integridade do contrato:
   ```bash
   npm run check
   ```
3. Veja o plano de execução dos containers:
   ```bash
   npm run plan
   ```
4. Suba a instância completa no Docker:
   ```bash
   npm run deploy
   ```

---

## Administrador, login e novos membros

O login é nativo do QM: os serviços `portal` (porta de entrada única) e `auth` (envia um link de acesso único por e-mail) já vêm em `services`. Não há senhas; quem não recebe link não entra.

| Onde | Chave | Efeito |
| :--- | :--- | :--- |
| `.env` | `ADMIN_GRANTS=voce@empresa.com:org_admin` | Primeiro administrador. O core concede `org_admin` ao subir. |
| `.env` | `AUTH_ALLOWED_EMAILS=a@x.com,b@y.com` | Quem pode pedir link de login (lista nomeada). |
| `qm.config.jsonc` | `env.auth.AUTH_ALLOWED_EMAIL_DOMAIN` | Alternativa à lista: admite o domínio inteiro da empresa. |
| `qm.config.jsonc` | `env.auth.AUTH_EMAIL_TRANSPORT` | `smtp` (qualquer caixa ou relay) ou `resend`. |
| `.env` | `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `AUTH_EMAIL_FROM` | Canal de envio dos links. Com Gmail: `smtp.gmail.com`, a conta, uma senha de app, e `AUTH_EMAIL_FROM` igual à conta. |

Grave segredos sempre com `npm exec qm -- secrets set CHAVE` (pede o valor sem ecoar). As chaves do broker (`AUTH_SIGNING_JWK`, `AUTH_TOKEN_SECRET`, `AUTH_CLIENT_SECRET`, `PORTAL_SESSION_SECRET`) são geradas por `npm exec qm -- setup`, ou à mão conforme os comentários de `.env.example`.

**Incluir um membro:** adicione o e-mail a `AUTH_ALLOWED_EMAILS` e rode `npm exec qm -- up`, ou use um domínio permitido para cobrir toda a empresa. Pessoas de fora do domínio são convidadas na aba **Users** do Admin (`<publicUrl>/admin`), com validade.

**Trocar o canal de e-mail** (Gmail → relay da empresa ou Resend) é só trocar os segredos e, se for Resend, `AUTH_EMAIL_TRANSPORT`; depois `check`, `doctor` e `up`. Usuários e sessões não mudam.

**Portas no alvo docker:** só a do portal (`basePort + 1`) deve ficar pública. Core, Web UI e Admin devem ser bloqueados de fora; `ops/install-firewall.sh` faz isso na cadeia `DOCKER-USER` (o `ufw` não alcança portas publicadas pelo Docker).

---

## Comandos Disponíveis

| Comando | Descrição |
| :--- | :--- |
| `npm run check` | Valida se `qm.config.jsonc`, skills e tools estão 100% corretos. |
| `npm run plan` | Mostra os containers e variáveis que serão executados sem iniciar nada. |
| `npm run deploy` | Inicia o banco PostgreSQL, o motor QM, o portal de login, a interface Web, o Admin e os Sandboxes. |
| `npm run status` | Exibe o status dos containers em execução. |
| `npx qm down` | Para os containers do cliente. |
| `npx qm outputs` | Exibe as URLs do painel Web e links do Slack. |

---

## Vantagens Deste Modelo para Clientes
- **Isolamento Total:** Cada cliente tem seu próprio repositório, suas chaves e suas skills.
- **Atualização Simplificada:** Quando sair uma nova versão do QM, basta atualizar o número da versão em `package.json` (`@yc-software/qm`) e rodar `npm install`. Não há risco de conflito de código.
- **Leveza:** O repositório contém apenas alguns KBs de regras e arquivos de configuração.
