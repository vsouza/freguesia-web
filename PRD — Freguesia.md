# PRD — Freguesia

Oct 12, 2026 · @Vinicius

## 1. Vision and problem

Freguesia is a mobile-first web catalog of verified WhatsApp numbers for restaurants (later pharmacies, grocery stores, hardware stores and pet shops) so regulars can order directly, with no delivery app in between. Tagline (pt-BR): "Pede direto. Paga preço de freguês." ("Order direct. Pay the regular's price.")

**The problem.** Delivery apps charge the restaurant a commission and the customer fees; restaurants pass part of that into the in-app menu. People who already know a place want to order directly but don't know the right number, whether the place takes WhatsApp orders, or whether it pays off.

**The proposal.** We are not a marketplace: there is no menu, price, payment or delivery inside the product. We deliver three things: the number verified by the restaurant itself; confirmation from the neighborhood that ordering direct worked; and the savings reported by regulars compared with the apps. Monetization comes later: a Promotions tab (restaurants pay to publish perks), a sponsored highlight on the place's own page, and ad-network slots (Google AdSense) on the home and detail pages.

**Pilot.** Belo Horizonte, Brazil; neighborhoods Savassi, Lourdes, Funcionários, Santa Tereza and Sion. Web (PWA) first; no native app in this phase. All code, identifiers, routes, comments and this document are in English; user-facing copy ships in Brazilian Portuguese through Gettext (`priv/gettext/pt_BR`), with English source strings.

## 2. Goals, non-goals and metrics

**Pilot goals (90 days after launch)**

1. 40 verified places across the 5 neighborhoods, each with photo and opening hours filled in.
2. Prove the loop works: every WhatsApp open triggers a confirmation prompt and at least 25% of prompts get an answer.
3. Show a savings average on at least half of the verified places (10+ reports each).
4. Zero legal complaints: no competitor brand named, no savings shown without attribution and period.

**Non-goals (out of this phase)**

- Menu, cart, payment, delivery tracking or anything that turns Freguesia into an intermediary of the order.
- Native iOS/Android app. The product is a PWA.
- Charging restaurants. The Promotions tab launches free and only becomes paid in phase 3.
- In-product chat; the conversation happens on WhatsApp.
- Other cities.

**Metrics**

| Metric | Definition | Pilot target |
| --- | --- | --- |
| Verified places | status `verified` with confirmed code | 40 |
| Verification rate | verified ÷ signups started | 60% |
| WhatsApp opens | clicks on "Order on WhatsApp" per week | 300/week |
| Return-prompt response rate | answers to "Did ordering direct work?" ÷ opens | 25% |
| "Worked" rate | "Yes" answers ÷ total answers, per place | > 85% |
| Savings coverage | places with 10+ reports in 90 days ÷ verified | 50% |
| Approval time | median between signup and backoffice approval | < 4 business hours |
| Scam reports | numbers flagged "wrong number or scam" per week | downward trend |
| Core Web Vitals | home LCP on 4G, p75 | < 2.5 s |

## 3. Users and personas

| Persona | Who | Wants | Where they enter the product |
| --- | --- | --- | --- |
| Regular (customer) | Lives or works in the pilot neighborhoods, already orders from 3 to 5 known places, uses WhatsApp all day | The right number, to know whether the place takes orders and whether direct pays off; no mandatory signup | Welcome → Location → Sign in (optional) → Home → Place details → WhatsApp → return prompt |
| Regular with account | Same person after signing in with Google or email | Favorites on any device, neighborhood promotions, reports with more weight | Sign in, Favorites, Promotions, Profile |
| Place owner or manager | Neighborhood restaurant with WhatsApp Business, usually 1 to 3 people answering | Appear verified, receive direct orders, publish a perk, pay no commission | Business account (Google, Apple or email), 3-step registration, delivery area, place page, promotions, own sponsored highlight |
| Backoffice operator | Freguesia team (the founder during the pilot) | Approve fast and safely, handle complaints, moderate perk and promotion copy | Admin web app |
| External advertiser | Local business without its own page (gas, water, producers) | Reach in the neighborhood | Ad-network slots; no self-serve panel in this phase |

## 4. Pillars and product rules

Three pillars carry trust: the restaurant verifies its own number; regulars confirm whether ordering direct worked; regulars report how much they saved. Everything on screen derives from one of the three and says where it came from.

**Mandatory rules (copy and layout)**

1. Never name or show competitor brands. The product says only "apps". Applies to copy, restaurant-provided perks, promotions and own ads; the backoffice blocks text containing a known brand (list kept in configuration).
2. Savings are always attributed to users, with count and period: "Reported by 52 regulars in the last 90 days. May vary." with a "How we calculate" link.
3. Average only with 10 or more reports in the 90-day window. Below that: "Few reports so far (n). Ordered direct? Tell us what you paid."
4. Perk (offer) only for verified places, always with "Provided by the restaurant" and the last-updated date. The card shows only the summary ("12% off"); the full text lives on the details page.
5. Unverified places show no photo, perk or savings; outline button "Open chat" and the warning "Don't send a Pix before confirming the order".
6. Ads are always labeled ("Ad" or "Sponsored"), never inside a place card, and never change the order of the "near you" list.
7. Fixed footer: "Freguesia is a catalog: we don't sell, charge or deliver orders. Price, payment and delivery are arranged directly with the business."
8. No green and no vivid delivery-app red-orange in the brand; the per-category color map may use other hues.

**Rules for third-party content**

- Perks, promotions and own ads go through moderation before publishing; text changes go back to the queue.
- Reports are anonymous on display and never show individual values, only aggregates.
- A "wrong number or scam" report opens a case in the backoffice and, with 2 reports in 7 days, hides the WhatsApp button until review.

## 5. Functional scope: consumer

Screens follow the design canvas (Freguesia in Claude Design). Routes are Phoenix Router paths; everything is LiveView unless stated.

| Screen | Route | What it does | Rules and states |
| --- | --- | --- | --- |
| Welcome | `/` (first visit) | Background photo, tagline, "Get started", link "I own a restaurant" | Shown once; cookie `onboarded` skips straight to the home |
| Location | `/location` | Asks for geolocation permission or manual neighborhood choice | Geo in the browser (JS hook); the point goes to the server only to compute which delivery areas cover it and is kept in the browser's encrypted session cookie, never in the database; "Not now" or denied: manual neighborhood choice, using the neighborhood centroid as the point |
| Sign in (optional) | `/sign-in` | Google, email magic link or "continue without an account" | An account never blocks usage; without one, favorites stay in `localStorage` |
| Home | `/home` | Segments (All, Restaurants, Pharmacies, Grocery, Hardware, Pet), food type, filters (open now, with direct perk, verified), accent-insensitive name search, list of places whose delivery area covers the user's point, ad slot after the 2nd card, "For businesses" band | Top gradient and chips follow the active category; a segment with no places shows "coming soon" with "Suggest a place"; empty search shows "Nothing found" and "Clear filters" |
| Place card | component | Name, category, neighborhood, status, badge, proof chips (savings, worked), photo, perk tag, "View and order" | Verified × unverified × few reports × closed; background from the category color map |
| Place details | `/places/:slug` | Large photo, badges, status, "Worked" and "Reported savings" tiles, full perk, ad slot, "About ordering direct", report, fixed "Order on WhatsApp" button and favorite | Button opens `wa.me/55<DDD><number>?text=...` with the default message and logs `whatsapp_open` |
| WhatsApp return | bottom sheet on details | "Did ordering direct work?" → Yes: savings band (same price, up to 10%, 10–20%, 20–30%, over 30%, didn't compare) → "Thanks" / No: reason (app only, no coverage in my area, no answer, wrong number or scam) | Triggered when the tab regains focus (`visibilitychange`) up to 2 h after the open; one answer per open; "Answer later" keeps the open pending |
| Page with own ad | details variant | "Ad · paid by the place" block with the day's promotion and a "Sponsored" card from another verified place | Verified only; moderated copy; "Why am I seeing this?" |
| Promotions | `/promotions` | Showcase of perks and promotions published by neighborhood places, sorted by date | Phase 2; each item links to details |
| Favorites | `/favorites` | List of saved places | Without account: local; with account: synced |
| Search | `/search` | Name search with recent history | Same normalization as the home (unaccent, lower, `&` → `e`) |
| Profile | `/profile` | Sign in, default neighborhood, my reports, sign out, delete account | Deleting anonymizes reports and removes favorites |
| Desktop | same routes | Full-size layouts per screen in section 12a: header navigation, 3-column grid, same card component | Breakpoints at 768 and 1024 px |

**Bottom navigation (mobile):** Home, Search, Promotions, Favorites, Profile. Active item in a black circle; Promotions gets a dot when there is a new item since the last visit.

**Deep link and sharing:** `/places/:slug` carries Open Graph tags with photo, name and badge; the restaurant can share its own link.

## 6. Functional scope: business (restaurant)

The business owner has an account from day one, created with Google, Apple or email/password through Firebase Authentication. The verified WhatsApp number still identifies the place; the account identifies the person who manages it and is where the delivery area, hours, perk and reports live. A full self-serve panel arrives in phase 3; in the pilot the account unlocks registration, delivery-area setup and the edit screens.

**Business account (`/business/sign-in`)**

- Providers in the pilot: Google, Apple and email/password; phone sign-in can be enabled later in the Firebase console without code changes on the server.
- The client uses the Firebase JS SDK; the server verifies the Firebase ID token in a Plug, creates or loads the `business_accounts` row by `firebase_uid` and opens a server session (7-day cookie). No Firebase call on later requests.
- One account can manage several places (`place_members`, roles `owner` and `manager`); the first account to register a place becomes its owner.
- Customer accounts stay on `phx.gen.auth` + Google (section 5); the two never mix.

**3-step registration (`/business/register`)**

1. Details: business name, type (Restaurant, Pharmacy, Grocery, Hardware, Pet), food type when restaurant, WhatsApp number, business neighborhood, delivery mode (own or partner courier), served neighborhoods (multi), optional perk for direct orders, terms acceptance. Validation: Brazilian E.164 WhatsApp number, neighborhood inside the pilot, name 3 to 60 characters.
2. WhatsApp: we send a 6-digit code through the WhatsApp Cloud API (authentication template). Valid for 10 min, 3 attempts, resend after 60 s. Once confirmed, the request enters the backoffice queue with status `pending`.
3. Done: success screen with next steps (photo, opening hours, perk). The place only appears in the catalog after human approval; until then the screen says "under review, up to 1 business day".

**After approval**

- Receives on WhatsApp the approval message with the page link and a signed edit link (30-day token) for photo, hours, perk and served neighborhoods.
- Opening hours per weekday; "open until" and "closed, opens at" are computed server-side in `America/Sao_Paulo`.
- Perk: short text (up to 80 characters) + tag summary (up to 14 characters). Every edit goes back to moderation and updates `offer_updated_at`.
- Pause: the business can mark itself "not serving today"; the card shows closed.

**Delivery area (`/business/places/:id/delivery-area`)**

1. The owner sets a radius in km from the place's point (0.5 to 6 km, step 0.5; default 3 km). The map draws the circle and shades every neighborhood polygon inside it.
2. Tapping a neighborhood on the map or in the list removes it from the area (bridge, hill, bad traffic); it shows hatched. The list is sorted by distance and shows the neighborhoods outside the radius as a hint to widen it.
3. Saving stores `delivery_areas` (radius) and `delivery_area_exclusions` (neighborhood ids) and recomputes the derived `place_coverage` cache. The card summary reads "Delivers in N neighborhoods · up to X km".
4. Required before the place goes live: a verified place without a delivery area shows "Set your delivery area" in the owner's screens and stays hidden from customers.
5. Map: MapLibre GL JS with free vector tiles; neighborhood polygons come from the city's open data stored in PostGIS. Without a map (old browser), the list alone still works.

**Promotions (phase 2) and own ad (phase 3)**

- Promotion: title, description, validity (up to 7 days), verified places only, moderated. Shown on the Promotions tab and at the top of the details page. Free during the pilot; paid per publication or monthly subscription in phase 3.
- Own ad: "Ad · paid by the place" block on the details page and a "Sponsored" card in the "Also in Savassi" section of other places in the same category. Never reorders the home list.

**Exit**: the business can request removal from its verified WhatsApp; the place becomes `removed`, leaves the catalog and aggregated reports are kept for 12 months for audit.

## 7. Functional scope: backoffice

The backoffice is a LiveView app under `/admin`, protected by email + password login with 2FA (TOTP), with roles `admin` and `moderator`. The pilot has 1 to 2 operators.

| Area | What it does | Rules |
| --- | --- | --- |
| Verifications | Request queue with filters (pending, new, in review, resubmitted, all), search, KPIs, review panel and actions Approve and publish, Request changes, Reject | Four automatic checks: code confirmed; WhatsApp Business profile name matches the given name (similarity ≥ 0.8); address inside the pilot; no open complaint. Approving requires all four ok or an internal note explaining why |
| Places | List and edit every place, pause, remove, reassign category, replace photo | Every edit is written to `audit_log` with operator, before and after |
| Complaints | Cases opened by "wrong number or scam" and by the "Report number" form | 2 complaints in 7 days hide the WhatsApp button automatically; the operator reopens, re-verifies (new code) or removes |
| Promotions | Moderation of promotions and perks (approve, request changes, reject) with card preview | Automatic block on terms from the competitor brand list and on comparative price language |
| Ads | List of active own ads, period, neighborhoods, payment status (phase 3); ad-network slot configuration (enabled, position, blocked categories) | Network slots never on an unverified place page |
| Reports | Aggregates per place: opens, answers, worked rate, savings distribution, fraud signals | Never shows identifiable individual answers; allows invalidating a batch by IP or device |

**Actions and effects**

- Approve and publish: place becomes `verified`, appears in the catalog, triggers the WhatsApp message with the link and the edit token.
- Request changes: status `needs_changes`, WhatsApp message with the reason (operator free text, with templates: photo, profile name, neighborhood outside the pilot).
- Reject: status `rejected`, reason required; the number may try again after 30 days.
- All actions are idempotent and recorded in `audit_log`.

## 8. Calculation rules

**Reported savings.** Each "Yes" answer with a chosen band becomes a report with the band midpoint: same price = 0, up to 10% = 5, 10–20% = 15, 20–30% = 25, over 30% = 35; "didn't compare" is excluded. The displayed average is the simple mean of valid reports from the last 90 days, rounded to an integer, and only appears with n ≥ 10.

```latex
\bar{e} = \frac{1}{n}\sum_{i=1}^{n} m_i,\quad n = |\{r : r.answered\_at \ge today - 90d,\ r.valid\}|,\quad n \ge 10
```

The histogram uses the five bands (0, ≤10, ≤20, ≤30, 30+) with the report count in each; the band containing the average is highlighted. Copy says "less, on average, than on the apps" and never a value in currency.

**"Worked" rate.** Shown as `yes/total in 30 days` (e.g. 31/33) and as a percentage bar. Only opens with an answer count; opens without an answer are excluded from the denominator. A place with fewer than 5 answers in 30 days shows the raw number without a bar.

**Open/closed status.** Computed per request from `opening_hours` (JSON per weekday, intervals in minutes) in the `America/Sao_Paulo` time zone; a "paused today" flag set by the business overrides it. Copy: "Open · until 10 pm" or "Closed · opens at 6 pm" (next interval, today or tomorrow).

**Home ordering.** 1) places whose delivery area covers the user's point; 2) open before closed; 3) verified before unverified; 4) more "worked" answers in the last 30 days; 5) name. Ads and promotions have no influence.

**Coverage query.** A place covers the user's point when the point is within the radius of the place's location and not inside any neighborhood the owner excluded. The home runs it once per session with the point rounded to 3 decimals (about 100 m); a manual neighborhood choice uses the neighborhood centroid.

```sql
SELECT p.id
FROM places p
JOIN delivery_areas d ON d.place_id = p.id AND d.active
WHERE p.status = 'verified'
  AND ST_DWithin(p.geom::geography, ST_SetSRID(ST_MakePoint($lng, $lat), 4326)::geography, d.radius_m)
  AND NOT EXISTS (
    SELECT 1 FROM delivery_area_exclusions x
    JOIN neighborhoods n ON n.id = x.neighborhood_id
    WHERE x.delivery_area_id = d.id
      AND ST_Contains(n.geom, ST_SetSRID(ST_MakePoint($lng, $lat), 4326))
  );
```

Indexes: GiST on `places.geom` and `neighborhoods.geom`; the exclusion check runs only for places already inside the radius. `place_coverage` (neighborhood → place) stays as a derived cache for the Promotions tab and for the backoffice, recomputed by an Oban job whenever an area or a polygon changes.

**Report anti-fraud.**

- One report per open; an open expires after 2 h without an answer.
- At most 3 reports per device per place per 30 days (signed cookie + light fingerprint); extras get `valid = false`.
- A report from a verified account (Google or email) weighs 1.0; without an account 0.7 in the weighted mean (from phase 2; equal weight during the pilot).
- A suspicious batch (more than 10 reports from the same /24 within 1 h) is flagged for review and excluded from the mean until an operator releases it.
- A "wrong number or scam" report counts as a "No" answer and opens a case.

## 9. Data model (PostgreSQL)

PostgreSQL 16 with the `unaccent`, `pg_trgm` (name search) and `postgis` (neighborhoods as polygons, places as points) extensions. UUID v7 primary keys; `inserted_at`/`updated_at` on every table; soft delete only on `places`.

| Table | Main columns | Notes |
| --- | --- | --- |
| `cities` | id, name, slug, state, active | BH in the pilot |
| `neighborhoods` | id, city\_id, name, slug, geom (polygon), pilot (bool) | Savassi, Lourdes, Funcionários, Santa Tereza, Sion |
| `segments` | id, key (restaurants, pharmacies, grocery, hardware, pet), name, color\_key | Color map by `color_key` |
| `categories` | id, segment\_id, key (pizza, mineira, burger, italian, japanese, acai…), name, color\_key | Food types and equivalents |
| `places` | id, name, slug, segment\_id, category\_id, neighborhood\_id, geom (point), whatsapp\_e164, wa\_profile\_name, status (pending, needs\_changes, rejected, verified, paused, hidden, removed), delivery\_mode (own, partner), opening\_hours (jsonb), photo\_key, paused\_until, verified\_at, removed\_at | Trigram index on `unaccent(lower(name))`; index on (neighborhood\_id, status) |
| `place_coverage` | place\_id, neighborhood\_id | Served neighborhoods (N:N) |
| `offers` | id, place\_id, text, tag, status (pending, approved, rejected), updated\_by\_place\_at, approved\_at | One active offer per place; history kept |
| `promotions` | id, place\_id, title, body, starts\_at, ends\_at, status, paid (bool), amount\_cents | Phase 2; `paid` only in phase 3 |
| `sponsorships` | id, place\_id, kind (own\_detail, also\_nearby), starts\_at, ends\_at, neighborhood\_ids (uuid\[\]), status, amount\_cents | Own ad, phase 3 |
| `verification_codes` | id, place\_id, code\_hash, expires\_at, attempts, confirmed\_at, channel | Code never stored in plain text |
| `verification_requests` | id, place\_id, status, checks (jsonb: code, profile\_name, in\_pilot, no\_complaints), notes, decided\_by, decided\_at | Backoffice queue |
| `users` | id, email (citext, unique), name, avatar\_url, provider (google, email), default\_neighborhood\_id, confirmed\_at, deleted\_at | Customer with account; deletion anonymizes |
| `user_tokens` | id, user\_id, token\_hash, context (magic\_link, session), sent\_to, expires\_at | `phx.gen.auth` default |
| `favorites` | user\_id, place\_id | Composite PK |
| `whatsapp_opens` | id, place\_id, user\_id (nullable), device\_id, neighborhood\_id, opened\_at, responded\_at | Every click on "Order on WhatsApp" |
| `reports` | id, open\_id, place\_id, user\_id (nullable), device\_id, outcome (worked, failed), savings\_band (none, le10, le20, le30, gt30, not\_compared), fail\_reason (app\_only, no\_coverage, no\_answer, wrong\_or\_scam), valid (bool), weight (numeric), answered\_at | Source of savings and the worked rate |
| `place_stats` | place\_id, window (30d, 90d), opens, responses, worked, savings\_avg, savings\_hist (jsonb), reports\_count, computed\_at | Materialized by a job every 15 min |
| `complaints` | id, place\_id, source (report, form), reason, details, status (open, reviewing, closed), resolution | Complaint cases |
| `ad_slots` | id, key (home\_after\_2, detail\_before\_about), network (adsense), enabled, blocked\_categories (text\[\]) | Slot configuration |
| `admins` | id, email, password\_hash, role (admin, moderator), totp\_secret | Backoffice |
| `audit_log` | id, admin\_id, action, entity, entity\_id, before (jsonb), after (jsonb), inserted\_at | Everything the backoffice does |
| `events` | id, name, props (jsonb), device\_id, user\_id, inserted\_at | First-party analytics, partitioned by month |

**Business accounts and delivery areas**

| Table | Main columns | Notes |
| --- | --- | --- |
| `business_accounts` | id, firebase\_uid (unique), email (citext), name, avatar\_url, provider (google, apple, password), last\_login\_at, disabled\_at | Created on first verified Firebase ID token |
| `place_members` | business\_account\_id, place\_id, role (owner, manager), inserted\_at | Composite PK; the registering account becomes owner |
| `delivery_areas` | id, place\_id (unique), radius\_m (500–6000), center (point, copied from `places.geom` at save), active, updated\_by (business\_account\_id) | One area per place; history in `audit_log` |
| `delivery_area_exclusions` | delivery\_area\_id, neighborhood\_id | Neighborhoods removed from the radius |

`place_coverage` becomes derived: recomputed from the area and the exclusions, never edited by hand.

**Decisions**

- `place_stats` is a table materialized by Oban, not a view: the home reads one row per place and never aggregates at request time.
- `whatsapp_opens` and `reports` are append-only; corrections set `valid = false`, never delete.
- Photos live in object storage; the database keeps only `photo_key`. The public URL goes through the CDN (section 15).
- Customer personal data is limited to email, name and avatar; `device_id` is a random UUID in a cookie, with no invasive fingerprinting.

## 10. Architecture and stack

A single Phoenix (Elixir) monolith serves the PWA, the backoffice and the integrations; PostgreSQL is the only database; Oban runs jobs inside the same Postgres; the CDN sits in front of photos and static assets and, if it pays off, of public HTML.

&#91;embedded content: architecture · 3 clients, 1 Phoenix monolith, 4 dependencies\]

Customers and the backoffice talk to LiveView; the Ecto contexts read and write Postgres; the business only receives messages through the WhatsApp Cloud API, called by the HTTP clients.

**Stack**

| Layer | Choice | Why |
| --- | --- | --- |
| Language and framework | Elixir 1.17, OTP 27, Phoenix 1.7 with LiveView 1.0 | One codebase for web, real time and jobs; low machine cost for pilot traffic |
| Database | PostgreSQL 16 + PostGIS + pg\_trgm + unaccent | Accent-insensitive name search, neighborhood by polygon, a single stateful dependency |
| Jobs | Oban (queue in Postgres) | No Redis; retries and scheduling out of the box |
| Front end | LiveView + Tailwind + minimal JS hooks (geolocation, `visibilitychange`, PWA) | No SPA; server-rendered HTML with interactivity where it matters |
| Authentication | `phx.gen.auth` (magic link) + Ueberauth Google; business owners through Firebase Authentication (Google, Apple, email/password), ID token verified server-side; admins with password + TOTP | Community standard, small surface |
| External HTTP | Req with retry and a simple per-integration circuit breaker | WhatsApp outage doesn't break registration |
| Photos | Direct upload to S3-compatible object storage, resized on upload (Image/Vix) | Database keeps only the key; CDN serves |
| Observability | Telemetry + PromEx (Prometheus/Grafana) + Sentry; structured JSON logs | Section 14 |
| Deploy | Elixir release in a container, `mix release`, migrations at boot | Section 15 |

**Contexts (domain modules)**

- `Catalog`: cities, neighborhoods, segments, categories, places, delivery areas and derived coverage, opening hours, offers, home search and ordering.
- `Verification`: registration, codes, automatic checks, queue and decisions; emits `place_verified` and `place_rejected` events.
- `Reports`: WhatsApp opens, answers, anti-fraud, complaints and the `place_stats` computation.
- `Accounts`: customers (Google, magic link), favorites, preferences, account deletion; business accounts (Firebase identity, place membership).
- `Admin`: operators, roles, 2FA, `audit_log`.
- `Ads`: network slots, promotions, sponsorships and their states.
- `Messaging`: WhatsApp Cloud API adapter (templates, delivery-status webhooks), with `Messaging.Fake` in dev and test.

**Folder structure**

```
lib/freguesia/            contexts and schemas
lib/freguesia_web/        router, live/, components/, controllers/ (OG, health, webhooks)
lib/freguesia/workers/    Oban workers
priv/repo/migrations/
priv/gettext/pt_BR/       UI translations (source strings in English)
assets/                   Tailwind, JS hooks, manifest.json, service worker
test/                     ExUnit + Wallaby for the critical flows
```

## 11. Integrations

| Integration | Use | How | Failure and fallback |
| --- | --- | --- | --- |
| WhatsApp Cloud API (Meta) | Verification code, approval or change-request message, edit link, complaint notice | Approved templates (*authentication* category for the code, *utility* for the rest); delivery-status webhook; Freguesia's own number with verified WhatsApp Business | Oban queue with exponential retry (5 attempts in 30 min); if the API is down the signup stays `pending` and the screen says "we'll send the code shortly"; manual option in the backoffice |
| `wa.me` deep link | "Order on WhatsApp" button | `https://wa.me/55<DDD><number>?text=<message>`; default message (pt-BR) "Oi! Vi o \<name> na Freguesia e quero pedir direto." (no tracking code in the text) | No dependency; we log the open before redirecting |
| Google Sign-In | Sign in with Google | Ueberauth Google (OAuth 2.0, scope `email profile`); official Google button on the front end | On failure, offer the magic link |
| Email magic link | Sign in with email | `phx.gen.auth` with a 15-minute token; delivery via Swoosh (Resend or Amazon SES) | Resend after 60 s; rate limit 5 per hour per email |
| Geolocation | Location screen | `navigator.geolocation` in a JS hook; the point goes to the server to resolve the neighborhood with PostGIS (`ST_Contains`) and to compute delivery coverage, and is kept only in the encrypted session cookie; the database keeps only `neighborhood_id` | Denied or outside the pilot: manual neighborhood choice |
| Google AdSense | `home_after_2` and `detail_before_about` slots | Native in-feed unit loaded after LCP, inside an `<aside aria-label="Ad">` with a fixed label; `data-ad-slot` per position; sensitive categories blocked | Empty slot collapses (no hole); toggled by a flag in the backoffice; never on an unverified place page |
| Object storage (S3-compatible) | Place photos | Signed direct upload from the business's browser (edit link); 800×450 and 240×240 variants generated by a worker | Missing photo shows the category placeholder |
| CDN | Photos, static assets and optionally public HTML | Section 15 | Direct origin if the CDN fails |
| Analytics | Product events | First-party `events` table + Plausible (cookieless) for page views | No Google Analytics in the pilot |

**Business side**

| Integration | Use | How | Failure and fallback |
| --- | --- | --- | --- |
| Firebase Authentication | Business owner account | Firebase JS SDK on the client (Google, Apple, email/password); the server verifies the ID token (RS256, Google public keys cached 6 h) in a Plug and issues its own 7-day session cookie; `firebase_uid` maps to `business_accounts` | Existing sessions keep working if Firebase is unreachable; sign-in shows a retry; no customer flow depends on Firebase |
| Map (delivery area) | Radius and neighborhood exclusions | MapLibre GL JS with free vector tiles (OpenFreeMap or Protomaps), neighborhood polygons served as GeoJSON from PostGIS, circle drawn client-side from the radius in meters | Tiles down: the polygons still render on a blank background; the list alone can edit the area |
| Neighborhood polygons | Coverage and exclusions | Belo Horizonte open data (PBH/IBGE) imported into `neighborhoods.geom`, simplified for the client (tolerance \~5 m) | Missing polygon: the neighborhood is treated as its centroid |

**Product events (fixed names)**: `onboarding_started`, `location_granted`, `location_manual`, `login_google`, `login_email_sent`, `home_viewed`, `category_selected`, `search_performed`, `place_viewed`, `whatsapp_open`, `return_prompt_shown`, `report_submitted`, `favorite_added`, `signup_started`, `signup_code_confirmed`, `ad_impression`, `ad_click`.

## 12. Design system and front end

The visual reference is the "Freguesia" canvas in Claude Design ("Visual system" board). The tokens below become CSS variables and the Tailwind config; no loose hex values in components.

**Typography.** Urbanist (Google Fonts, weights 300 italic, 400, 500, 600, 700, 800, 900), served through the CDN with `font-display: swap`. Two-beat headings: line 1 italic 300, line 2 bold 800 with negative tracking. Minimum 12 px on mobile.

**Base colors**

| Token | Value | Use |
| --- | --- | --- |
| `ink` | #141414 | Text, primary button, active nav, dark tiles |
| `ink-2` | #3A3634 | Italic line of headings |
| `muted` | #6F6A66 | Captions (AA on white) |
| `line` | #ECE7E1 | Thin borders, inputs, ad slot |
| `sand` | #F6F1EA | Neutral blocks, inactive chips |
| `peach` | #FBDDB8 | Default gradient top |
| `tomato-500` / `tomato-600` | #F0582B / #C8441A | Icons and dots / text and links |
| `gold` | #F5B82E | Savings number and average band on `ink` |
| `indigo-800` / `indigo-100` | #1C2C6B / #E2E7F7 | Verified badge, nothing else |
| `saffron-800` / `saffron-100` | #7A4F08 / #FAEBC6 | Caution and scam warnings |

**Category color map** (`top` = gradient start, `tint` = card background, `accent` = chip text and outline)

| Category (color key) | top | tint | accent |
| --- | --- | --- | --- |
| Restaurants / All (`peach`) | #FBDDB8 | #FBF3E3 | #C8441A |
| Pizza (`tomato`) | #F8C9B9 | #FBE2D8 | #B5361C |
| Grocery (`orange`) | #F8D3A8 | #FBE8D0 | #8F4A05 |
| Mineira (`corn`) | #F5E093 | #FAF0C9 | #705000 |
| Burger (`cocoa`) | #DEC5B2 | #EDDFD4 | #5C3A24 |
| Italian (`wine`) | #F0C6CD | #F8E0E4 | #8A2538 |
| Pet (`pitaya`) | #F2CEE4 | #F8E3F0 | #8E2E6B |
| Açaí (`grape`) | #D9C9E8 | #EBE3F2 | #553175 |
| Japanese (`indigo`) | #CBD9EC | #E2EAF4 | #2A4A7A |
| Pharmacies (`water`) | #C9E3E8 | #E0F0F2 | #1C5C66 |
| Hardware (`concrete`) | #DEDBD7 | #ECEAE7 | #4A4440 |

The map lives in `Catalog.ColorMap` (keyed by the `color_key` of segments and categories) and is exposed as `bg-cat-*` and `text-cat-*` classes; unverified places use `sand`.

**Shape.** Corners 28 px on sheets and banners, 24 px on cards and photos, 18 px on tiles and notices, pill (999 px) on buttons, chips, inputs, tags and the bottom nav. Shadows: card `0 1px 2px rgba(20,20,20,.05), 0 10px 30px rgba(20,20,20,.08)`; nav `0 14px 36px rgba(20,20,20,.16)`; tilted tag `0 4px 14px rgba(20,20,20,.14)`. Stroke icons with round caps; a generic chat bubble instead of the WhatsApp logo.

**Components (Phoenix function components in `FreguesiaWeb.Components`)**: `app_shell` (category gradient top + bottom nav), `place_card`, `proof_chip`, `verified_badge`, `offer_tag`, `stat_tile`, `savings_mini_hist`, `offer_band`, `warning_box`, `ad_slot`, `bottom_sheet` (WhatsApp return), `segment_chips`, `category_chips`, `filter_chips`, `search_field`, `empty_state`, `coming_soon`, `primary_button`, `outline_button`, `icon_button`.

**PWA and performance.** `manifest.json` with icon and `ink` theme color; service worker caching static assets and photos (stale-while-revalidate) plus an offline page; budget: initial JS up to 90 kB gzip, LCP < 2.5 s on 4G, WebP images with `srcset`. Mobile-first with a 768 px breakpoint for the 3-column grid.

**Accessibility.** AA contrast on all text, 44 px touch targets, visible input labels, `aria-pressed` on chips and filters, `aria-current` on navigation, `role="img"` with a description on the mini histogram, color never the only signal.

## 12a. Mobile web and full-size desktop

Freguesia ships two experiences from one codebase and one set of LiveViews: the mobile web app (phones, the primary surface) and the full-size site (laptops and desktops). There is no separate `m.` domain and no user-agent sniffing: the same HTML is served, CSS breakpoints pick the layout, and a few components render both variants with only one visible. Mobile is designed first; the full-size layout is a deliberate design, not a stretched phone screen.

**Breakpoints and containers**

| Range | Name | Container | Grid | Navigation |
| --- | --- | --- | --- | --- |
| ≤ 767 px | mobile | full width, 20 px gutters, max 430 px centered on wider phones | 1 column | Bottom bar (Home, Search, Promotions, Favorites, Profile) |
| 768–1023 px | tablet | 720 px, 24 px gutters | 2 columns | Top header with links; bottom bar hidden |
| 1024–1439 px | desktop | 1200 px, 24 px gutters | 3 columns | Top header: logo, search field, links, location pill |
| ≥ 1440 px | wide | 1280 px, centered | 3 columns (cards up to 400 px) | Same as desktop |

**Layout per screen**

| Screen | Mobile web | Full-size |
| --- | --- | --- |
| Welcome, Location, Sign in | Full-bleed photo with a glass panel at the bottom | Split: photo fills the left half, the panel sits centered on the right (max 480 px); on tablet the photo becomes a top band |
| Home | Gradient top, pill search + filter button, chip rows, card list, ad after the 2nd card, bottom bar | Header with search inline and the category gradient as a band; chips on one row; 3-column card grid; the ad occupies grid slot 3 as an in-feed card; "For businesses" band and footer in two columns |
| Place card | Full width, photo 116 px on the right | Same component; in the grid the card is a fixed-height tile with the photo at 132 px |
| Place details | Photo circle on the gradient, sheet below, fixed bottom button, return prompt as a bottom sheet | Two columns: left column with photo, proof tiles, perk, ad slot and "About"; right column a sticky panel (name, status, category, delivery, "Order on WhatsApp", favorite); the return prompt becomes a centered modal |
| Search | Own screen with history | Inline in the header; results replace the home grid; `/` focuses the field |
| Promotions, Favorites, Profile | Own screens from the bottom bar | Pages under the header; Favorites and Promotions use the same 3-column grid |
| Business sign in and registration | Stacked form, fixed bottom button | Centered card (max 560 px) with the steps as a left rail; the sticky button stays inside the card |
| Delivery area | Map 350×380, slider and list below | Map takes 60% of the width and the full viewport height; slider, summary and neighborhood list in a right column; mouse wheel zooms, click toggles a polygon |
| Business panel (phase 3) | Stacked cards, bottom bar with Places, Reports, Promotions, Account | Left sidebar, content area, same pattern as the backoffice |
| Backoffice | Supported from 768 px as a stacked list with the review panel as a drawer; approvals work but are secondary | Primary surface at ≥ 1024 px: sidebar, queue, review panel side by side |

**Interaction differences on full-size**

- Hover states on cards (lift 2 px, stronger shadow), chips and buttons; focus rings visible on keyboard navigation.
- Keyboard: `/` focuses search, `Esc` closes modals and the return prompt, arrow keys move through the grid.
- Proof chips show a tooltip with the attribution text ("Reported by 52 regulars…") instead of relying on the details page.
- Modals replace bottom sheets; toasts replace inline confirmations where space allows.
- The location pill opens a popover with the manual neighborhood list; geolocation works the same way.

**Assets and performance**

- Photos served with `srcset` at 240, 480 and 800 px widths and `sizes` per breakpoint; the details photo grows from 250 to 320 px on desktop.
- Same JS budget on all sizes (90 kB gzip initial); the map library loads only on the delivery-area screen.
- Core Web Vitals targets apply to both: LCP < 2.5 s on 4G mobile and < 1.5 s on desktop broadband; CLS < 0.1 (card tiles have fixed aspect ratios).

**SEO and sharing**

- One canonical URL per place (`/places/:slug`) for every screen size; Open Graph and JSON-LD `LocalBusiness` rendered server-side.
- Public pages (home, place details, promotions) are crawlable without JavaScript; the LiveView socket only enhances them.

**Testing**

- Wallaby suites run at 390×844 and 1280×800; critical flows must pass on both.
- Visual snapshots of home, details, delivery area and backoffice at 390, 768 and 1280 px on every PR (Percy or a self-hosted equivalent).
- The design canvas holds "Home desktop · 1280" today; desktop boards for details, business registration and delivery area are an open design task before phase 1 ends.

## 13. Security, privacy and LGPD

The product stores little: the business's WhatsApp number (public by nature) and, only for those who sign in, email, name and avatar. Legal basis: contract performance for the account and the registration; legitimate interest for aggregated reports and product events, with opt-out.

| Topic | Decision |
| --- | --- |
| Location | Coordinates are never persisted; they become `neighborhood_id` within the same request and are discarded. The screen copy says so. |
| Reports | Anonymous on display; `device_id` is a UUID in a signed `SameSite=Lax`, `HttpOnly` cookie; no hardware fingerprinting. |
| Customer account | Deleting the account anonymizes reports (`user_id = null`), removes favorites and tokens within 24 h; confirmation email. |
| Business | Number shown only after verification; removal on request from the verified WhatsApp itself; aggregated reports retained for 12 months. |
| Backoffice | Argon2 passwords, mandatory TOTP, 8-hour session, immutable `audit_log`, optional IP allowlist. |
| Edit links | Random 32-byte token, hashed in the database, 30-day validity, revocable from the backoffice. |
| Transport and headers | HTTPS only, HSTS, strict CSP (own scripts + Google Fonts + AdSense), `Referrer-Policy: strict-origin-when-cross-origin`. |
| Rate limits | Per IP and per `device_id`: verification code 3/10 min, magic link 5/h, reports 3 per place/30 days, search 60/min (Hammer or PlugAttack). |
| Third-party content | Perks, promotions and own ads go through moderation; blocked brand list in configuration; text sanitized (no HTML). |
| Policies | Terms, Privacy and "How we calculate" pages versioned in the repository; acceptance recorded with a timestamp at registration. |
| Secrets | Environment variables injected at deploy; never in the repository; WhatsApp token rotated every 90 days. |
| Backups | Daily encrypted dump with 30-day retention + 7-day PITR; restore tested monthly. |

**Customer location.** The point is rounded to 3 decimals before any use, lives only in the encrypted browser session cookie, never reaches the database or the logs (request and LiveView logs filter it), and is replaced by the neighborhood centroid when the user chooses manually. Business owners' Firebase data is limited to uid, email, name, avatar and provider; Firebase itself is configured without analytics.

## 14. Observability, resilience and quality

The pilot runs on one instance, so what protects the product is degrading well, not scaling: every external dependency has a fallback that keeps the "Order on WhatsApp" button working.

**Observability**

- Metrics: Telemetry + PromEx exporting to Prometheus/Grafana (p50/p95 latency per LiveView, errors, Oban queue, Ecto pool, VM).
- Errors: Sentry with release and anonymized user.
- Logs: structured JSON with `request_id`, hashed `device_id`, `place_id`; 30-day retention.
- Health: `/health` (app) and `/health/deep` (database, storage, WhatsApp API with a 60 s cache).
- Product dashboard: opens, answers, worked rate, signups per step, approvals per day, ad impressions and clicks.

**Pilot SLOs**

| Indicator | Target |
| --- | --- |
| Home and details availability | 99.5% monthly |
| Home p95 latency (server) | < 300 ms |
| Verification code delivery | 95% within 60 s |
| `place_stats` lag | < 20 min |

**Resilience**

- Circuit breaker per integration (WhatsApp, storage, email); when open, the flow continues with an honest message and a queued retry.
- Materialized `place_stats`: a job failure freezes the numbers, it doesn't take the home down.
- Ad slots load after LCP and collapse on failure.
- Migrations always backward compatible (expand/contract); zero-downtime deploys.
- Light chaos test before launch: take down the fake WhatsApp and the storage in staging and verify the fallbacks.

**Quality**

- ExUnit with at least 80% coverage on contexts; property tests for search normalization and the savings computation.
- Wallaby on the critical flows: register → code → approval → card live; open WhatsApp → return → report → average.
- CI: `mix format --check-formatted`, Credo, Dialyzer, Sobelow, tests, release build; automatic deploy to staging, manual to production.
- Seed data with the 6 fictional places from the canvas and the 5 pilot neighborhoods.

## 15. Infrastructure, deploy and CDN evaluation

The pilot runs in one region (São Paulo) with one app instance, a managed Postgres and object storage; the CDN comes last, once there is real traffic and real photos to measure. Figures below are approximate (recalled from public price lists, not quoted on this date) and must be checked at decision time.

**Pilot topology**

| Piece | Initial choice | Alternative | Approximate monthly cost |
| --- | --- | --- | --- |
| App (Elixir release in a container) | Fly.io, region `gru`, 1 shared-cpu 1 GB machine; a second machine only for zero-downtime deploys | Render, Railway, Hetzner VPS with Docker | US$ 10 to 25 |
| PostgreSQL | Fly Postgres (1 node, 1 GB) or Neon/Supabase with PostGIS | Managed Postgres on AWS/GCP (pricier) | US$ 15 to 30 |
| Object storage | Cloudflare R2 (no egress fees) | Backblaze B2, AWS S3 | < US$ 5 |
| Transactional email | Resend or Amazon SES | Postmark | US$ 0 to 20 |
| WhatsApp Cloud API | Authentication and utility conversations billed per conversation (Brazil, cents of a dollar each) | — | US$ 5 to 30 in the pilot |
| Observability | Grafana Cloud free + Sentry free | Self-hosted | US$ 0 |
| Domain and DNS | Cloudflare DNS | Route 53 | US$ 1 to 3 |

**What the CDN must do here**

1. Serve place photos (WebP, two sizes) and static assets (CSS, JS, fonts) with long cache and compression.
2. Optional in phase 3: cache public HTML of the home and details for 60 s with purge on place approval or edit (LiveView connects after the HTML).
3. Edge protection: TLS, HTTP/3, basic rate limiting and WAF against bots on the code and report endpoints.
4. PoP in Brazil: photo latency to BH is what the customer feels.

**Candidates and criteria**

| CDN | Approximate egress (South America) | PoP in Brazil | Pros | Cons | Fit |
| --- | --- | --- | --- | --- | --- |
| Cloudflare (Free/Pro) | Included in the plan; Pro \~US$ 20–25/month | Yes (São Paulo, Rio, others) | DNS, WAF, rate limiting and R2 integrated; free R2 egress; best cost | HTML caching needs careful rules around the LiveView websocket; Free tier limits rules | Favorite for the pilot |
| Bunny.net | \~US$ 0.03/GB at volume (São Paulo) | Yes | Simple, cheap, built-in image optimizer | No robust WAF; own storage separate from R2 | Good for photos only |
| AWS CloudFront | \~US$ 0.11/GB after the free tier (1 TB/month) | Yes (São Paulo, Rio) | Integrates with S3 and WAF | Pricier per GB and per request; more configuration | Only if the stack moves to AWS |
| Fastly | From \~US$ 50/month | Yes | Instant purge, great for HTML | High price for pilot volume | Phase 3 if HTML caching proves worth it |

**How to decide (end of phase 1)**: measure 30 days of production without a CDN: GB of photos served, p75 LCP on 4G in BH, and storage egress cost. If LCP > 2.5 s or egress exceeds \~100 GB/month, enable the CDN for photos and static assets (Cloudflare with R2 is the lowest-friction path); cache HTML only if server p95 exceeds 300 ms with `place_stats` caching already on.

**Deploy and environments**

- `dev` locally with Docker Compose (Postgres+PostGIS, MinIO, Mailpit, `Messaging.Fake`).
- `staging` identical to production, with a test WhatsApp number and AdSense in test mode.
- `prod` deployed by tag via GitHub Actions: release build, migration at boot (`Freguesia.Release.migrate`), rollout across two machines.
- Variables: `DATABASE_URL`, `SECRET_KEY_BASE`, `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID`, `GOOGLE_CLIENT_ID/SECRET`, `S3_*`, `ADSENSE_CLIENT`, `SENTRY_DSN`.

## 16. Roadmap and definition of done

18 weeks in four phases; each gate is a measured criterion, not a date. The CDN is decided and enabled in phase 3, with production data in hand.

&#91;embedded content: roadmap · 4 phases, 3 gates\]

The pilot (phase 1) is the bet: we only move to accounts and promotions once there are 40 verified places and a 25% response rate to the WhatsApp return prompt.

**Deliverables per phase**

| Phase | Deliverables | Exit gate |
| --- | --- | --- |
| 0 · Foundation | Repository, CI, Docker Compose, `phx.gen.auth` for admins, section 9 migrations, design-system tokens and base components, seeds with neighborhoods and 6 fictional places, staging deploy | G1: register → code (fake) → approval → card live, running in staging |
| 1 · Pilot | Welcome, location, home, details, return prompt and reports, `place_stats`, business account (Firebase Auth), 3-step registration with real WhatsApp, delivery-area setup (radius + exclusions) with the neighborhood polygons imported, backoffice (verifications, places, complaints), legal pages, PWA, observability; launch in Savassi with 15 invited places | G2: 40 verified across the 5 neighborhoods and 25% response rate for 2 consecutive weeks |
| 2 · Accounts | Sign in with Google and email, synced favorites, profile and account deletion, search with history, Promotions tab (free), promotion moderation, AdSense in both slots, report weight by account | G3: savings average shown on 50% of verified places; AdSense revenue measured |
| 3 · Revenue | Paid promotions and own ads (Pix payment through a gateway), business panel with WhatsApp login, CDN decision and rollout, HTML caching if needed, second city under evaluation | First 10 paying places and infra cost < 15% of revenue |

**Definition of done (every story)**: tests passing in CI; no accessibility regression (axe in Wallaby); copy reviewed against the section 4 rules; product event emitted; a metric or log to operate it; staging deploy validated on a phone.

## 17. Risks, dependencies and open questions

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Meta rejects templates or limits Freguesia's number | Registration stalls | Templates submitted in phase 0; fallback verification by operator phone call recorded in the backoffice |
| Few reports per place (loop doesn't close) | No savings average, pillar 3 never shows | Automatic prompt on return from WhatsApp, one-tap question, "Answer later"; nudge in favorites |
| Fraudulent reports (a business inflating its own average) | Loss of trust | Per-device limits, weight by account, suspicious batches held for review, average only with 10+ |
| Complaints from delivery apps or restaurants about comparisons | Legal | Section 4 rules enforced in code (copy tests), savings always attributed, never a competitor brand |
| Scams with fake numbers | Harm to customers and the brand | Only verified places show perk and photo; Pix warning; complaint hides the button after 2 cases |
| A single backoffice operator | Queue grows, slow approval | 4-business-hour target; message to the business with the deadline; automatic checks reduce the work |
| WhatsApp API cost growing with volume | Margin | Transactional messages only; no WhatsApp marketing |
| Reliance on AdSense for early revenue | Low, volatile revenue | Paid promotions and own ads in phase 3 as the main revenue |

**External dependencies**: WhatsApp Business account verified by Meta; Google Cloud project for OAuth, a Firebase project for business authentication (Apple sign-in needs an Apple Developer account), neighborhood polygons from the city's open data, and an approved AdSense account (requires a live domain with content); company registration (CNPJ) and terms reviewed by a lawyer before launch.

**Open questions**

- [ ] Does verification require a CNPJ or is the WhatsApp Business number enough? (proposal: number only in the pilot)
- [ ] Does a restaurant that takes WhatsApp orders but is also on the apps join normally? (proposal: yes; the product doesn't judge)
- [ ] Keep savings bands in percent, or ask for the amount in currency in phase 2?
- [ ] Paid promotion per publication or monthly subscription? Target price?
- [ ] Second city: Contagem/Nova Lima (neighbors) or another capital?
- [ ] Final name and domain (freguesia.app, pededireto.com.br)?
- [ ] Photos: does the business upload its own, or does Freguesia shoot the first 40?
