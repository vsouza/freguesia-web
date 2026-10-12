# Freguesia

A web catalog (PWA) of verified WhatsApp numbers for restaurants and local businesses in Belo Horizonte. The full product spec is in `PRD — Freguesia.md` (in Portuguese, the product language).

Current status: phase 0 (foundation) is done and phase 1 is in progress. Phase 1 starts with the WhatsApp loop: the customer clicks "order on WhatsApp", the opening is recorded, a return sheet asks whether the order worked, and the answers feed the savings and success figures.

## Run locally

Requirements: Elixir 1.19 / OTP 28 and Docker.

```sh
docker compose up -d          # Postgres 16 + PostGIS on port 5433
mix setup                     # deps, database, migrations, seeds and assets
mix phx.server                # http://localhost:4000
```

If port 5433 is taken, set `POSTGRES_PORT=<port>` (it applies to dev and test).

### Walk through the flows

1. Customer signup: open `/cadastrar`, fill in the form, and read the WhatsApp code in `/admin/mensagens-fake` (the fake WhatsApp inbox).
2. Backoffice: sign in at `/admin/entrar` with `admin@freguesia.local` / `senha-dev-freguesia-2026`. On the first login, set up the authenticator app (2FA is required).
3. In `/admin/verificacoes`, open a request, approve it, and check the card at `/bairro/savassi`.
4. WhatsApp loop: open a place, click "Pedir no WhatsApp" (it opens in a new tab), then go back to the first tab. The return sheet asks whether the order worked.

## Checks (same as CI)

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix sobelow --exit medium
mix dialyzer
mix test --cover              # coverage threshold: 80%
```

## Structure

- `lib/freguesia/`: domain. `Catalog` (neighborhoods, places, opening hours), `Verification` (signup, code, queue, decisions), `Reports` (openings, answers, complaints, antifraud, stats), `Admin` (operators, 2FA, `audit_log`), `Messaging` (WhatsApp; the `Fake` adapter is used in dev and staging), `Events` (product analytics).
- `lib/freguesia_web/`: screens. Neighborhood home, place details, 3-step signup, and the backoffice under `/admin`.
- `priv/repo/migrations/`: the schema from section 9 of the PRD, plus later additions.
- `test/`: domain, LiveView and end-to-end tests, including the G1 flow in `test/freguesia_web/g1_test.exs`.

## Known gaps

- The real WhatsApp adapter (`Messaging.Cloud`) and the Meta templates are not done yet. Staging uses the fake adapter.
- The Fly staging app does not exist yet. `fly.toml` describes it but nothing has been deployed.
- Rate limits (verification code per IP, backoffice login) are not implemented.
- The neighborhood polygons in the seeds are approximate and only for development.
- The six places in the seeds are placeholders.
