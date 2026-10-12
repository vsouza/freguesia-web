# Freguesia

Catálogo web (PWA) de números de WhatsApp verificados de restaurantes e comércios de Belo Horizonte. A especificação completa está em `PRD — Freguesia.md`.

Esta é a fase 0 (fundação). Ela cobre o fluxo cadastro → código → aprovação → card no ar, que é o portão G1 do PRD.

## Rodar localmente

Pré-requisitos: Elixir 1.19 / OTP 28, Docker.

```sh
docker compose up -d          # Postgres 16 + PostGIS na porta 5433
mix setup                     # deps, banco, migrações, seeds e assets
mix phx.server                # http://localhost:4000
```

Se a porta 5433 estiver ocupada, use `POSTGRES_PORT=<porta>` (vale para dev e test).

### Como testar o fluxo

1. Freguês: `/cadastrar` → preencha o formulário → o código aparece em **`/admin/mensagens-fake`** (fake do WhatsApp).
2. Backoffice: `/admin/entrar` com `admin@freguesia.local` / `senha-dev-freguesia-2026`. No primeiro login, cadastre o app autenticador (2FA é obrigatório).
3. Em `/admin/verificacoes`, abra o pedido, aprove e confira o card em `/bairro/savassi`.

## Checagens (o mesmo que o CI roda)

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix sobelow --exit medium
mix dialyzer
mix test --cover              # limite de cobertura: 80%
```

## Estrutura

- `lib/freguesia/` — domínio: `Catalog` (bairros, lugares, horário), `Verification` (cadastro, código, fila, decisões), `Admin` (operadores, 2FA, `audit_log`), `Messaging` (WhatsApp, com adaptador `Fake` em dev/staging).
- `lib/freguesia_web/` — telas: home do bairro, detalhes, cadastro em 3 passos; backoffice em `/admin`.
- `priv/repo/migrations/` — schema da seção 9 do PRD.
- `test/` — domínio, LiveViews e o teste de ponta a ponta do G1 (`test/freguesia_web/g1_test.exs`).

## Pendências conhecidas da fase 0

- Adaptador real do WhatsApp (`Messaging.Cloud`) e a conta da Meta: fase 1. Staging usa o fake.
- Staging no Fly ainda não existe: `fly.toml` descreve, mas o app não foi criado.
- Rate limit (código por IP, login do backoffice) e edição do restaurante pelo link: fase 1.
- Polígonos dos bairros nas seeds são aproximados, só para dev.
- Nomes dos 6 lugares das seeds são provisórios; trocar pelos do canvas.
