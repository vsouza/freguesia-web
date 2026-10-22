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

## Business sign-in (Firebase)

Business accounts sign in with Google, Apple or e-mail and password through Firebase Authentication (PRD §6). In dev and test there is no Firebase project: the page offers a development e-mail sign-in instead, and the Google and Apple buttons stay disabled.

To turn the real sign-in on, set these variables (all four, or the buttons stay disabled):

- `FIREBASE_API_KEY`: the Web API key. The server also uses it to verify ID tokens (`accounts:lookup`).
- `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`: from the Firebase console's web app settings.

Production also switches the server to the Firebase identity adapter (`config/runtime.exs`). The browser SDK is in `assets/js/firebase_sign_in.js` and is loaded only on the sign-in page.

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
- The search rate limit (PRD §13: 60/min) is not implemented. The verification code and backoffice login limits are in `Freguesia.RateLimit`, kept in each machine's memory, so with two machines a client can get up to twice the limit.
- The neighborhood polygons in the seeds are approximate and only for development.
- Firebase sign-in is wired but not yet run against a real Firebase project: the browser flow and the token check need a project with Google and Apple enabled.
- The delivery-area screen has no map yet (PRD §6 asks for MapLibre); the owner sets the point with "Use my location" and edits the radius and neighborhoods in a list.
- The six places in the seeds are placeholders.
