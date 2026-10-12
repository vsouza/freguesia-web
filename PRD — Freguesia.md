# PRD — Freguesia

Oct 12, 2026 · @Vinicius

## 1. Visão e problema

A Freguesia é um catálogo web mobile-first de números de WhatsApp verificados de restaurantes (e, depois, farmácias, mercados, construção e pet) para o freguês pedir direto, sem app de entrega no meio. Tagline: "Pede direto. Paga preço de freguês."

**O problema.** Apps de entrega cobram comissão do restaurante e taxas do cliente; o restaurante repassa parte disso no cardápio do app. Quem já conhece a casa quer pedir direto, mas não sabe qual é o número certo, se o lugar atende por WhatsApp e se compensa.

**A proposta.** Não somos marketplace: não há cardápio, preço, pagamento nem entrega dentro do produto. Entregamos três coisas: o número verificado pelo próprio restaurante; a confirmação pela vizinhança de que pedir direto funcionou; e a economia relatada pelos fregueses em relação aos apps. Monetização posterior: aba Promoções (restaurantes pagam para publicar vantagens), destaque patrocinado do próprio lugar e slots de rede de anúncios (Google AdSense) na home e nos detalhes.

**Piloto.** Belo Horizonte, bairros Savassi, Lourdes, Funcionários, Santa Tereza e Sion. Web (PWA) primeiro; sem app nativo nesta fase.

## 2. Objetivos, não-objetivos e métricas

**Objetivos do piloto (90 dias após o lançamento)**

1. Ter 40 lugares verificados nos 5 bairros, com foto e horário preenchidos.
2. Provar que o loop funciona: toda abertura de WhatsApp gera uma pergunta de confirmação e pelo menos 25% delas recebem resposta.
3. Exibir média de economia em pelo menos metade dos lugares verificados (10+ relatos cada).
4. Zero reclamação jurídica: nenhuma marca de concorrente citada, nenhuma economia exibida sem atribuição e período.

**Não-objetivos (fora desta fase)**

- Cardápio, carrinho, pagamento, rastreio de entrega ou qualquer coisa que transforme a Freguesia em intermediária do pedido.
- App nativo iOS/Android. O produto é PWA.
- Cobrança dos restaurantes. A aba Promoções nasce gratuita e só vira paga na fase 3.
- Chat dentro do produto; a conversa acontece no WhatsApp.
- Outras cidades.

**Métricas**

| Métrica | Definição | Meta do piloto |
| --- | --- | --- |
| Lugares verificados | status `verified` com código confirmado | 40 |
| Taxa de verificação | verificados ÷ cadastros iniciados | 60% |
| Aberturas de WhatsApp | cliques em "Pedir no WhatsApp" por semana | 300/semana |
| Taxa de resposta ao retorno | respostas à pergunta "Conseguiu pedir direto?" ÷ aberturas | 25% |
| Taxa "funcionou" | respostas "Sim" ÷ respostas totais, por lugar | > 85% |
| Cobertura de economia | lugares com 10+ relatos em 90 dias ÷ verificados | 50% |
| Tempo de aprovação | mediana entre cadastro e aprovação no backoffice | < 4 h úteis |
| Denúncias de golpe | números marcados como "errado ou golpe" por semana | tendência de queda |
| Core Web Vitals | LCP na home em 4G, p75 | < 2,5 s |

## 3. Usuários e personas

| Persona | Quem é | O que quer | Onde entra no produto |
| --- | --- | --- | --- |
| Freguês | Mora ou trabalha nos bairros do piloto, já pede de 3 a 5 lugares conhecidos, usa WhatsApp o dia inteiro | O número certo, saber se atende e se compensa pedir direto; sem cadastro obrigatório | Inicial → Localização → Entrar (opcional) → Home → Detalhes → WhatsApp → retorno |
| Freguês com conta | O mesmo, depois de entrar com Google ou e-mail | Favoritos em qualquer aparelho, promoções do bairro, relatos com mais peso | Entrar, Favoritos, Promoções, Perfil |
| Dono ou gerente do lugar | Restaurante de bairro com WhatsApp Business, geralmente 1 a 3 pessoas atendendo | Aparecer verificado, receber pedidos direto, publicar uma vantagem, não pagar comissão | Cadastro em 3 passos, página do lugar, promoções, destaque próprio |
| Operador do backoffice | Time da Freguesia (no piloto, o fundador) | Aprovar rápido com segurança, tratar denúncias, moderar texto de vantagens e promoções | Backoffice web |
| Anunciante externo | Negócio local sem página própria (gás, água, produtor) | Alcance no bairro | Slots de rede de anúncios; sem painel próprio nesta fase |

## 4. Pilares e regras do produto

Três pilares sustentam a confiança: o restaurante verifica o próprio número; os fregueses confirmam se pedir direto funcionou; os fregueses relatam quanto economizaram. Tudo que aparece na tela deriva de um desses três e diz de onde veio.

**Regras obrigatórias (texto e layout)**

1. Nunca citar nem mostrar marcas de concorrentes. O produto diz só "apps". Vale para copy, vantagens informadas por restaurantes, promoções e anúncios próprios; o backoffice bloqueia texto com marca conhecida (lista mantida em configuração).
2. Economia sempre atribuída aos usuários, com quantidade e período: "Relatado por 52 fregueses nos últimos 90 dias. Pode variar." com link "Como calculamos".
3. Média só com 10 ou mais relatos na janela de 90 dias. Abaixo disso: "Poucos relatos até agora (n). Pediu direto? Conte quanto pagou."
4. Oferta (vantagem) só de lugar verificado, sempre com "Informado pelo restaurante" e a data da última atualização. No card aparece só o resumo ("12% off"); o texto completo fica nos Detalhes.
5. Lugar não verificado não mostra foto, oferta nem economia; botão de contorno "Abrir conversa" e aviso "Não faça Pix antes de confirmar o pedido".
6. Anúncios sempre rotulados ("Anúncio" ou "Patrocinado"), nunca dentro do card de um lugar, e nunca alteram a ordem da lista "perto de você".
7. Rodapé fixo: "A Freguesia é um catálogo: não vendemos, não cobramos e não entregamos pedidos. Preço, pagamento e entrega são combinados direto com o estabelecimento."
8. Sem verde, sem o vermelho-laranja vivo dos apps de entrega na marca; o mapa de cor por categoria pode usar outras matizes.

**Regras de conteúdo gerado por terceiros**

- Vantagem, promoção e anúncio próprio passam por moderação antes de ir ao ar; mudanças de texto voltam para a fila.
- Relatos são anônimos na exibição e nunca mostram valores individuais, só agregados.
- Denúncia "número errado ou golpe" abre um caso no backoffice e, com 2 denúncias em 7 dias, esconde o botão de WhatsApp até revisão.

## 5. Escopo funcional: consumidor

As telas seguem o canvas de design (Freguesia no Claude Design). Rotas são as do Phoenix Router; tudo é LiveView salvo onde indicado.

| Tela | Rota | O que faz | Regras e estados |
| --- | --- | --- | --- |
| Inicial | `/` (1ª visita) | Foto de fundo, tagline, "Começar", link "Tenho um restaurante" | Mostrada uma vez; cookie `onboarded` pula direto para a home |
| Localização | `/localizacao` | Pede permissão de geolocalização ou escolha manual do bairro | Geo só no navegador (hook JS); servidor recebe apenas o bairro resolvido; "Agora não" leva à home com Savassi como padrão |
| Entrar (opcional) | `/entrar` | Google, e-mail por link mágico ou "continuar sem conta" | Conta nunca bloqueia o uso; sem conta, favoritos ficam em `localStorage` |
| Home | `/bairro/:slug` | Segmentos (Todos, Restaurantes, Farmácias, Mercados, Construção, Pet), tipo de comida, filtros (aberto agora, com vantagem, verificados), busca por nome sem acento, lista de cards, slot de anúncio após o 2º card, faixa "Para quem vende" | Degradê do topo e chips seguem a categoria ativa; segmento sem lugares mostra "chegam em breve" com "Indicar um lugar"; busca vazia mostra "Nada encontrado" e "Limpar filtros" |
| Card do lugar | componente | Nome, categoria, bairro, status, selo, chips de prova (economia, funcionou), foto, etiqueta da vantagem, "Ver e pedir" | Verificado × não verificado × poucos relatos × fechado; fundo pelo mapa de cor da categoria |
| Detalhes | `/lugar/:slug` | Foto grande, selos, status, tiles "Funcionou" e "Economia relatada", vantagem completa, slot de anúncio, "Sobre o pedido direto", denúncia, botão fixo "Pedir no WhatsApp" e favoritar | Botão abre `wa.me/55DDDNÚMERO?text=...` com mensagem padrão e registra `whatsapp_open` |
| Retorno do WhatsApp | folha inferior nos Detalhes | "Conseguiu pedir direto?" → Sim: faixa de economia (mesmo preço, até 10%, 10–20%, 20–30%, mais de 30%, não comparei) → "Valeu" / Não: motivo (só atende pelo app, não entrega no meu bairro, não respondeu, número errado ou golpe) | Disparada quando a aba volta ao foco (`visibilitychange`) até 2 h após a abertura; uma resposta por abertura; "Responder depois" guarda a abertura pendente |
| Página com anúncio próprio | variante dos Detalhes | Bloco "Anúncio · pago pelo lugar" com promoção do dia e card "Patrocinado" de outro lugar verificado | Só para verificados; texto moderado; "Por que vejo isso?" |
| Promoções | `/promocoes` | Vitrine das vantagens e promoções publicadas pelos lugares do bairro, ordenada por data | Fase 2; cada item leva aos Detalhes |
| Favoritos | `/favoritos` | Lista dos lugares salvos | Sem conta: local; com conta: sincronizado |
| Buscar | `/buscar` | Busca por nome com histórico recente | Mesma normalização da home (unaccent, lower, `&` → `e`) |
| Perfil | `/perfil` | Entrar, bairro padrão, meus relatos, sair, apagar conta | Apagar conta anonimiza relatos e remove favoritos |
| Desktop | mesmas rotas | Grade de 3 colunas, busca no header, mesmo componente de card | Breakpoint em 768 px |

**Barra inferior (mobile):** Início, Buscar, Promoções, Favoritos, Perfil. Item ativo em círculo preto; Promoções ganha ponto quando há item novo desde a última visita.

**Deep link e compartilhamento:** `/lugar/:slug` tem Open Graph com foto, nome e selo; o restaurante pode divulgar o próprio link.

## 6. Escopo funcional: restaurante

O restaurante não tem login no piloto: toda a relação passa pelo número de WhatsApp verificado, que funciona como identidade. Um painel próprio entra na fase 3.

**Cadastro em 3 passos (`/cadastrar`)**

1. Dados: nome do negócio, tipo (Restaurante, Farmácia, Mercado, Construção, Pet), tipo de comida quando restaurante, WhatsApp, bairro do negócio, forma de entrega (própria ou motoboy parceiro), bairros atendidos (múltiplo), vantagem opcional para quem pede direto, aceite dos termos. Validação: WhatsApp no formato E.164 brasileiro, bairro dentro do piloto, nome com 3 a 60 caracteres.
2. WhatsApp: enviamos um código de 6 dígitos pelo WhatsApp Cloud API (template de autenticação). Validade 10 min, 3 tentativas, reenvio após 60 s. Confirmado o código, o pedido entra na fila do backoffice com status `pending`.
3. Pronto: tela de sucesso com próximos passos (foto, horário, vantagem). O lugar só aparece no catálogo depois da aprovação humana; até lá a tela diz "em análise, até 1 dia útil".

**Depois de aprovado**

- Recebe pelo WhatsApp a mensagem de aprovação com o link da página e um link de edição assinado (token de 30 dias) para foto, horário, vantagem e bairros atendidos.
- Horário por dia da semana; o status "aberto até" e "fechado, abre às" é calculado no servidor em `America/Sao_Paulo`.
- Vantagem: texto curto (até 80 caracteres) + resumo para etiqueta (até 14 caracteres). Toda edição volta para moderação e atualiza `offer_updated_at`.
- Pausar: o restaurante pode se marcar "sem atender hoje"; o card mostra fechado.

**Promoções (fase 2) e anúncio próprio (fase 3)**

- Promoção: título, descrição, validade (até 7 dias), só para verificados, moderada. Aparece na aba Promoções e no topo dos Detalhes. Gratuita no piloto; cobrança por publicação ou assinatura mensal na fase 3.
- Anúncio próprio: bloco "Anúncio · pago pelo lugar" nos Detalhes e card "Patrocinado" na seção "Também na Savassi" de outros lugares da mesma categoria. Nunca reordena a lista da home.

**Saída**: o restaurante pode pedir remoção pelo WhatsApp; o lugar vira `removed`, some do catálogo e os relatos são mantidos agregados por 12 meses para auditoria.

## 7. Escopo funcional: backoffice

O backoffice é um LiveView em `/admin`, protegido por login com e-mail + senha e 2FA (TOTP), com papel `admin` ou `moderator`. No piloto são 1 a 2 operadores.

| Área | O que faz | Regras |
| --- | --- | --- |
| Verificações | Fila de pedidos com filtros (pendentes, novos, em análise, reenviados, todos), busca, indicadores, painel de análise e ações Aprovar e publicar, Pedir ajuste, Recusar | Quatro checagens automáticas: código confirmado; nome do perfil WhatsApp Business bate com o nome informado (similaridade ≥ 0,8); endereço dentro do piloto; sem denúncia aberta. Aprovar exige as quatro ok ou uma nota interna justificando |
| Lugares | Lista e edição de todos os lugares, pausar, remover, reatribuir categoria, trocar foto | Toda edição grava em `audit_log` com operador, antes e depois |
| Denúncias | Casos abertos por "número errado ou golpe" e por formulário "Denunciar número" | 2 denúncias em 7 dias escondem o botão de WhatsApp automaticamente; o operador reabre, re-verifica (novo código) ou remove |
| Promoções | Moderação de promoções e vantagens (aprovar, pedir ajuste, recusar) com pré-visualização do card | Bloqueio automático de termos da lista de marcas de concorrentes e de linguagem de preço comparativo |
| Anúncios | Lista de anúncios próprios ativos, período, bairros, status de pagamento (fase 3); configuração dos slots de rede (ligado, posição, categorias bloqueadas) | Slots de rede nunca em página de lugar não verificado |
| Relatos | Agregados por lugar: aberturas, respostas, taxa funcionou, distribuição de economia, sinais de fraude | Nunca mostra respostas individuais com identificação; permite invalidar um lote por IP ou dispositivo |

**Ações e efeitos**

- Aprovar e publicar: lugar vira `verified`, aparece no catálogo, dispara mensagem WhatsApp com o link e o token de edição.
- Pedir ajuste: status `needs_changes`, mensagem WhatsApp com o motivo (texto livre do operador, modelos prontos: foto, nome do perfil, bairro fora do piloto).
- Recusar: status `rejected`, motivo obrigatório; o número pode tentar de novo depois de 30 dias.
- Todas as ações são idempotentes e registradas em `audit_log`.

## 8. Regras de cálculo

**Economia relatada.** Cada resposta "Sim" com faixa escolhida vira um relato com o ponto médio da faixa: mesmo preço = 0, até 10% = 5, 10–20% = 15, 20–30% = 25, mais de 30% = 35; "não comparei" não entra. A média exibida é a média simples dos relatos válidos dos últimos 90 dias, arredondada para inteiro, e só aparece com n ≥ 10.

```latex
\bar{e} = \frac{1}{n}\sum_{i=1}^{n} m_i,\quad n = |\{r : r.answered\_at \ge hoje - 90d,\ r.valid\}|,\quad n \ge 10
```

O histograma usa as cinco faixas (0, ≤10, ≤20, ≤30, 30+) com a contagem de relatos em cada uma; a faixa que contém a média é destacada. O texto diz "a menos, em média, do que nos apps" e nunca o valor em reais.

**Taxa "funcionou".** Exibida como `sim/total em 30 dias` (ex.: 31/33) e como percentual na barra. Entram só aberturas com resposta; aberturas sem resposta não contam no denominador. Lugar com menos de 5 respostas em 30 dias mostra o número cru sem barra.

**Status aberto/fechado.** Calculado por requisição a partir de `opening_hours` (JSON por dia da semana, intervalos em minutos) no fuso `America/Sao_Paulo`; "pausado hoje" pelo restaurante sobrepõe. Texto: "Aberto · até 22h" ou "Fechado · abre às 18h" (próximo intervalo, hoje ou amanhã).

**Ordenação da home.** 1) lugares que atendem o bairro ativo; 2) abertos antes de fechados; 3) verificados antes de não verificados; 4) mais respostas "funcionou" nos últimos 30 dias; 5) nome. Anúncios e promoções não influenciam.

**Antifraude dos relatos.**

- Um relato por abertura; abertura expira em 2 h sem resposta.
- No máximo 3 relatos por dispositivo por lugar por 30 dias (cookie assinado + fingerprint leve); excedentes ficam `valid = false`.
- Relato de conta verificada (Google ou e-mail) pesa 1,0; sem conta pesa 0,7 no cálculo da média ponderada (vale a partir da fase 2; no piloto, peso igual).
- Lote suspeito (mais de 10 relatos do mesmo /24 em 1 h) é marcado para revisão e não entra na média até o operador liberar.
- Denúncia "número errado ou golpe" conta como resposta "Não" e abre caso.

## 9. Modelo de dados (PostgreSQL)

PostgreSQL 16 com as extensões `unaccent`, `pg_trgm` (busca por nome) e `postgis` (bairros como polígonos e lugares como pontos). Chaves primárias UUID v7; `inserted_at`/`updated_at` em todas as tabelas; soft delete só em `places`.

| Tabela | Campos principais | Observações |
| --- | --- | --- |
| `cities` | id, name, slug, state, active | BH no piloto |
| `neighborhoods` | id, city\_id, name, slug, geom (polygon), pilot (bool) | Savassi, Lourdes, Funcionários, Santa Tereza, Sion |
| `segments` | id, key (restaurants, pharmacies, markets, construction, pet), name, color\_key | Mapa de cor por `color_key` |
| `categories` | id, segment\_id, key (pizza, mineira, burger, italian, japanese, acai…), name, color\_key | Tipo de comida e equivalentes |
| `places` | id, name, slug, segment\_id, category\_id, neighborhood\_id, geom (point), whatsapp\_e164, wa\_profile\_name, status (pending, needs\_changes, rejected, verified, paused, hidden, removed), delivery\_mode (own, partner), opening\_hours (jsonb), photo\_key, paused\_until, verified\_at, removed\_at | Índice trigram em `unaccent(lower(name))`; índice em (neighborhood\_id, status) |
| `place_coverage` | place\_id, neighborhood\_id | Bairros atendidos (N:N) |
| `offers` | id, place\_id, text, tag, status (pending, approved, rejected), updated\_by\_place\_at, approved\_at | Uma oferta ativa por lugar; histórico mantido |
| `promotions` | id, place\_id, title, body, starts\_at, ends\_at, status, paid (bool), amount\_cents | Fase 2; `paid` só na fase 3 |
| `sponsorships` | id, place\_id, kind (own\_detail, also\_nearby), starts\_at, ends\_at, neighborhoods (uuid\[\]), status, amount\_cents | Anúncio próprio, fase 3 |
| `verification_codes` | id, place\_id, code\_hash, expires\_at, attempts, confirmed\_at, channel | Código nunca em texto puro |
| `verification_requests` | id, place\_id, status, checks (jsonb: code, profile\_name, in\_pilot, no\_reports), notes, decided\_by, decided\_at | Fila do backoffice |
| `users` | id, email (citext, único), name, avatar\_url, provider (google, email), default\_neighborhood\_id, confirmed\_at, deleted\_at | Freguês com conta; apagar conta anonimiza |
| `user_tokens` | id, user\_id, token\_hash, context (magic\_link, session), sent\_to, expires\_at | Padrão `phx.gen.auth` |
| `favorites` | user\_id, place\_id | PK composta |
| `whatsapp_opens` | id, place\_id, user\_id (nullable), device\_id, neighborhood\_id, opened\_at, responded\_at | Cada clique em "Pedir no WhatsApp" |
| `reports` | id, open\_id, place\_id, user\_id (nullable), device\_id, outcome (worked, failed), savings\_band (none, le10, le20, le30, gt30, not\_compared), fail\_reason (app\_only, no\_coverage, no\_answer, wrong\_or\_scam), valid (bool), weight (numeric), answered\_at | Fonte da economia e da taxa funcionou |
| `place_stats` | place\_id, window (30d, 90d), opens, responses, worked, savings\_avg, savings\_hist (jsonb), reports\_count, computed\_at | Materializada por job a cada 15 min |
| `complaints` | id, place\_id, source (report, form), reason, details, status (open, reviewing, closed), resolution | Denúncias |
| `ad_slots` | id, key (home\_after\_2, detail\_before\_about), network (adsense), enabled, blocked\_categories (text\[\]) | Configuração dos slots |
| `admins` | id, email, password\_hash, role (admin, moderator), totp\_secret | Backoffice |
| `audit_log` | id, admin\_id, action, entity, entity\_id, before (jsonb), after (jsonb), inserted\_at | Tudo que o backoffice faz |
| `events` | id, name, props (jsonb), device\_id, user\_id, inserted\_at | Analytics próprio, particionada por mês |

**Decisões**

- `place_stats` é uma tabela materializada por Oban, não uma view: a home lê um registro por lugar e nunca agrega em tempo de requisição.
- `whatsapp_opens` e `reports` são append-only; correções viram `valid = false`, nunca delete.
- Fotos ficam em object storage; o banco guarda só a `photo_key`. A URL pública passa pela CDN (seção 15).
- Dados pessoais do freguês se resumem a e-mail, nome e avatar; `device_id` é um UUID aleatório em cookie, sem fingerprint invasivo.

## 10. Arquitetura e stack

Um único monólito Phoenix (Elixir) serve o PWA, o backoffice e as integrações; PostgreSQL é o único banco; Oban faz os jobs dentro do mesmo Postgres; a CDN fica na frente de fotos e estáticos e, se compensar, do HTML público.

&#91;embedded content: arquitetura · 3 clientes, 1 monólito Phoenix, 4 dependências\]

O freguês e o backoffice falam com o LiveView; os contextos Ecto leem e escrevem no Postgres; o restaurante só recebe mensagens pela WhatsApp Cloud API, chamada pelos clientes HTTP.

**Stack**

| Camada | Escolha | Por quê |
| --- | --- | --- |
| Linguagem e framework | Elixir 1.17, OTP 27, Phoenix 1.8 com LiveView 1.1 | Uma base de código para web, tempo real e jobs; baixo custo de máquina para o tráfego do piloto |
| Banco | PostgreSQL 16 + PostGIS + pg\_trgm + unaccent | Busca por nome sem acento, bairro por polígono, uma única dependência de estado |
| Jobs | Oban (fila no Postgres) | Sem Redis; retries e agendamento prontos |
| Front | LiveView + Tailwind + hooks JS mínimos (geolocalização, `visibilitychange`, PWA) | Sem SPA; HTML do servidor com interatividade onde importa |
| Autenticação | `phx.gen.auth` (magic link) + Ueberauth Google; admins com senha + TOTP | Padrão da comunidade, pouca superfície |
| HTTP externo | Req com retry e um circuit breaker simples por integração | WhatsApp fora do ar não derruba cadastro |
| Fotos | Upload direto para object storage compatível com S3, redimensionamento no upload (Image/Vix) | Banco guarda só a chave; CDN serve |
| Observabilidade | Telemetry + PromEx (Prometheus/Grafana) + Sentry; logs estruturados JSON | Seção 14 |
| Deploy | Release Elixir em container, `mix release`, migrações no boot | Seção 15 |

**Contextos (módulos de domínio)**

- `Catalog`: cidades, bairros, segmentos, categorias, lugares, cobertura, horários, ofertas, busca e ordenação da home.
- `Verification`: cadastro, códigos, checagens automáticas, fila e decisões; emite eventos `place_verified`, `place_rejected`.
- `Reports`: aberturas de WhatsApp, respostas, antifraude, denúncias e o cálculo de `place_stats`.
- `Accounts`: freguês (Google, magic link), favoritos, preferências, exclusão de conta.
- `Admin`: operadores, papéis, 2FA, `audit_log`.
- `Ads`: slots de rede, promoções, patrocínios e seus estados.
- `Messaging`: adaptador do WhatsApp Cloud API (templates, webhooks de status), com `Messaging.Fake` em dev e teste.

**Estrutura de pastas**

```
lib/freguesia/            contextos e schemas
lib/freguesia_web/        router, live/, components/, controllers/ (OG, health, webhooks)
lib/freguesia/workers/    Oban workers
priv/repo/migrations/
assets/                   Tailwind, hooks JS, manifest.json, service worker
test/                     ExUnit + Wallaby para os fluxos críticos
```

## 11. Integrações

| Integração | Uso | Como | Falha e fallback |
| --- | --- | --- | --- |
| WhatsApp Cloud API (Meta) | Código de verificação, mensagem de aprovação ou ajuste, link de edição, aviso de denúncia | Templates aprovados (categoria *authentication* para o código, *utility* para o resto); webhook de status de entrega; número da Freguesia com WhatsApp Business verificado | Fila Oban com retry exponencial (5 tentativas em 30 min); se a API cair, o cadastro fica `pending` e a tela diz "vamos mandar o código em instantes"; opção manual no backoffice |
| Deep link `wa.me` | Botão "Pedir no WhatsApp" | `https://wa.me/55<DDD><número>?text=<mensagem>`; mensagem padrão "Oi! Vi o \<nome> na Freguesia e quero pedir direto." (sem código de rastreio no texto) | Nenhuma dependência; registramos a abertura antes de redirecionar |
| Google Sign-In | Entrar com Google | Ueberauth Google (OAuth 2.0, escopo `email profile`); botão oficial do Google no front | Se falhar, oferece o link mágico |
| Link mágico por e-mail | Entrar com e-mail | `phx.gen.auth` com token de 15 min; envio via Swoosh (Resend ou Amazon SES) | Reenvio após 60 s; rate limit 5 por hora por e-mail |
| Geolocalização | Tela de localização | `navigator.geolocation` num hook JS; o ponto vai ao servidor só para resolver o bairro com PostGIS (`ST_Contains`) e é descartado; guardamos só o `neighborhood_id` | Negada ou fora do piloto: escolha manual do bairro |
| Google AdSense | Slots `home_after_2` e `detail_before_about` | Unidade nativa in-feed carregada após o LCP, dentro de um `<aside aria-label="Anúncio">` com rótulo fixo; `data-ad-slot` por posição; bloqueio de categorias sensíveis | Slot vazio colapsa (sem buraco); desligado por bandeira no backoffice; nunca em página de lugar não verificado |
| Object storage (S3-compatível) | Fotos dos lugares | Upload assinado direto do navegador do restaurante (link de edição), versões 800×450 e 240×240 geradas por worker | Foto ausente mostra o placeholder da categoria |
| CDN | Fotos, estáticos e, opcionalmente, HTML público | Seção 15 | Origem direta se a CDN falhar |
| Analytics | Eventos de produto | Tabela `events` própria + Plausible (sem cookies) para páginas | Sem Google Analytics no piloto |

**Eventos de produto (nomes fixos)**: `onboarding_started`, `location_granted`, `location_manual`, `login_google`, `login_email_sent`, `home_viewed`, `category_selected`, `search_performed`, `place_viewed`, `whatsapp_open`, `return_prompt_shown`, `report_submitted`, `favorite_added`, `signup_started`, `signup_code_confirmed`, `ad_impression`, `ad_click`.

## 12. Design system e front-end

A referência visual é o canvas "Freguesia" no Claude Design (quadro "Sistema visual"). Os tokens abaixo viram variáveis CSS e a configuração do Tailwind; nenhum hex entra solto nos componentes.

**Tipografia.** Urbanist (Google Fonts, pesos 300 itálico, 400, 500, 600, 700, 800, 900), servida pela CDN com `font-display: swap`. Títulos em dois tempos: linha 1 itálico 300, linha 2 negrito 800 com tracking negativo. Mínimo 12 px no celular.

**Cores base**

| Token | Valor | Uso |
| --- | --- | --- |
| `ink` | #141414 | Texto, botão primário, nav ativa, tiles escuros |
| `ink-2` | #3A3634 | Linha itálica dos títulos |
| `muted` | #6F6A66 | Legendas (AA sobre branco) |
| `line` | #ECE7E1 | Bordas finas, inputs, slot de anúncio |
| `sand` | #F6F1EA | Blocos neutros, chips inativos |
| `peach` | #FBDDB8 | Topo do degradê padrão |
| `tomato-500` / `tomato-600` | #F0582B / #C8441A | Ícones e pontos / texto e links |
| `gold` | #F5B82E | Número de economia e faixa da média sobre `ink` |
| `indigo-800` / `indigo-100` | #1C2C6B / #E2E7F7 | Selo Verificado, só ele |
| `saffron-800` / `saffron-100` | #7A4F08 / #FAEBC6 | Avisos de atenção e golpe |

**Mapa de cor por categoria** (`top` = início do degradê, `tint` = fundo do card, `accent` = texto e contorno do chip)

| Categoria | top | tint | accent |
| --- | --- | --- | --- |
| Restaurantes / Todos (Pêssego) | #FBDDB8 | #FBF3E3 | #C8441A |
| Pizza (Tomate) | #F8C9B9 | #FBE2D8 | #B5361C |
| Mercados (Laranja) | #F8D3A8 | #FBE8D0 | #8F4A05 |
| Mineira (Milho) | #F5E093 | #FAF0C9 | #705000 |
| Hambúrguer (Cacau) | #DEC5B2 | #EDDFD4 | #5C3A24 |
| Italiana (Vinho) | #F0C6CD | #F8E0E4 | #8A2538 |
| Pet (Pitaya) | #F2CEE4 | #F8E3F0 | #8E2E6B |
| Açaí (Uva) | #D9C9E8 | #EBE3F2 | #553175 |
| Japonesa (Índigo) | #CBD9EC | #E2EAF4 | #2A4A7A |
| Farmácias (Água) | #C9E3E8 | #E0F0F2 | #1C5C66 |
| Construção (Concreto) | #DEDBD7 | #ECEAE7 | #4A4440 |

O mapa vive em `Catalog.ColorMap` (chave `color_key` de segmentos e categorias) e é exposto como classes `bg-cat-*` e `text-cat-*`; lugar não verificado usa `sand`.

**Forma.** Cantos 28 px em folhas e banners, 24 px em cards e fotos, 18 px em tiles e avisos, pílula (999 px) em botões, chips, inputs, etiquetas e barra de navegação. Sombras: card `0 1px 2px rgba(20,20,20,.05), 0 10px 30px rgba(20,20,20,.08)`; nav `0 14px 36px rgba(20,20,20,.16)`; etiqueta inclinada `0 4px 14px rgba(20,20,20,.14)`. Ícones de traço com pontas redondas; balão genérico no lugar do logo do WhatsApp.

**Componentes (Phoenix function components em `FreguesiaWeb.Components`)**: `app_shell` (degradê do topo por categoria + barra inferior), `place_card`, `proof_chip`, `verified_badge`, `offer_tag`, `stat_tile`, `savings_mini_hist`, `offer_band`, `warning_box`, `ad_slot`, `bottom_sheet` (retorno do WhatsApp), `segment_chips`, `category_chips`, `filter_chips`, `search_field`, `empty_state`, `coming_soon`, `primary_button`, `outline_button`, `icon_button`.

**PWA e performance.** `manifest.json` com ícone e cor de tema `ink`; service worker com cache de estáticos e fotos (stale-while-revalidate) e página offline; orçamento: JS inicial até 90 kB gzip, LCP < 2,5 s em 4G, imagens em WebP com `srcset`. Mobile-first com breakpoint em 768 px para a grade de 3 colunas.

**Acessibilidade.** Contraste AA em todo texto, alvos de toque de 44 px, labels visíveis nos inputs, `aria-pressed` em chips e filtros, `aria-current` na navegação, `role="img"` com descrição no mini-histograma, cor nunca como único sinal.

## 13. Segurança, privacidade e LGPD

O produto guarda pouco: o número de WhatsApp do negócio (dado público por natureza) e, só para quem entra, e-mail, nome e avatar. Base legal: execução de contrato para a conta e o cadastro; legítimo interesse para os relatos agregados e os eventos de produto, com opt-out.

| Tema | Decisão |
| --- | --- |
| Localização | Coordenada nunca persiste; vira `neighborhood_id` no mesmo request e é descartada. Texto da tela diz isso. |
| Relatos | Anônimos na exibição; `device_id` é UUID em cookie `SameSite=Lax`, `HttpOnly`, assinado; sem fingerprint de hardware. |
| Conta do freguês | Apagar conta anonimiza relatos (`user_id = null`), remove favoritos e tokens em até 24 h; e-mail de confirmação. |
| Restaurante | Número exibido só após verificação; remoção a pedido pelo próprio WhatsApp verificado; relatos agregados retidos 12 meses. |
| Backoffice | Senha com Argon2, TOTP obrigatório, sessão de 8 h, `audit_log` imutável, IP allowlist opcional. |
| Links de edição | Token aleatório de 32 bytes, hash no banco, validade 30 dias, revogável no backoffice. |
| Transporte e cabeçalhos | HTTPS only, HSTS, CSP estrita (scripts próprios + Google Fonts + AdSense), `Referrer-Policy: strict-origin-when-cross-origin`. |
| Rate limit | Por IP e por `device_id`: código de verificação 3/10 min, link mágico 5/h, relatos 3 por lugar/30 dias, busca 60/min (Hammer ou PlugAttack). |
| Conteúdo de terceiros | Vantagens, promoções e anúncios próprios passam por moderação; lista de marcas bloqueadas em configuração; texto sanitizado (sem HTML). |
| Políticas | Páginas Termos, Privacidade e "Como calculamos" versionadas no repositório; aceite registrado com data no cadastro. |
| Segredos | Variáveis de ambiente injetadas no deploy; nunca no repositório; rotação do token do WhatsApp a cada 90 dias. |
| Backups | Dump diário criptografado com retenção de 30 dias + PITR de 7 dias; restauração testada mensalmente. |

## 14. Observabilidade, resiliência e qualidade

O piloto roda com uma instância, então o que protege o produto é degradar bem, não escalar: toda dependência externa tem um fallback que mantém o botão "Pedir no WhatsApp" funcionando.

**Observabilidade**

- Métricas: Telemetry + PromEx exportando para Prometheus/Grafana (latência p50/p95 por LiveView, erros, fila Oban, pool do Ecto, VM).
- Erros: Sentry com release e usuário anonimizado.
- Logs: JSON estruturado com `request_id`, `device_id` hash, `place_id`; retenção de 30 dias.
- Health: `/health` (app) e `/health/deep` (banco, storage, WhatsApp API com cache de 60 s).
- Painel de produto: aberturas, respostas, taxa funcionou, cadastros por etapa, aprovações por dia, impressões e cliques de anúncio.

**SLOs do piloto**

| Indicador | Objetivo |
| --- | --- |
| Disponibilidade da home e dos detalhes | 99,5% mensal |
| Latência p95 da home (servidor) | < 300 ms |
| Entrega do código de verificação | 95% em até 60 s |
| Atraso de `place_stats` | < 20 min |

**Resiliência**

- Circuit breaker por integração (WhatsApp, storage, e-mail); aberto, o fluxo segue com mensagem honesta e retry em fila.
- `place_stats` materializada: queda do job congela os números, não derruba a home.
- Slots de anúncio carregam depois do LCP e colapsam se falharem.
- Migrações sempre compatíveis para trás (expand/contract); deploy sem downtime.
- Teste de caos leve antes do lançamento: derrubar o WhatsApp fake e o storage em staging e verificar os fallbacks.

**Qualidade**

- ExUnit com cobertura mínima de 80% nos contextos; testes de propriedade para a normalização de busca e o cálculo de economia.
- Wallaby nos fluxos críticos: cadastro → código → aprovação → card no ar; abrir WhatsApp → retorno → relato → média.
- CI: `mix format --check-formatted`, Credo, Dialyzer, Sobelow, testes, build do release; deploy automático para staging, manual para produção.
- Dados de seed com os 6 lugares fictícios do canvas e as 5 vizinhanças do piloto.

## 15. Infra, deploy e avaliação de CDN

O piloto roda em uma região (São Paulo), com uma instância da app, um Postgres gerenciado e object storage; a CDN entra por último, quando houver tráfego e fotos reais para medir. Valores abaixo são aproximados (memória de listas públicas, não cotados nesta data) e devem ser conferidos na decisão.

**Topologia do piloto**

| Peça | Escolha inicial | Alternativa | Custo mensal aproximado |
| --- | --- | --- | --- |
| App (release Elixir em container) | Fly.io, região `gru`, 1 máquina shared-cpu 1 GB; segunda máquina só para deploy sem downtime | Render, Railway, VPS Hetzner com Docker | US$ 10 a 25 |
| PostgreSQL | Fly Postgres (1 nó, 1 GB) ou Neon/Supabase com PostGIS | Managed Postgres na AWS/GCP (mais caro) | US$ 15 a 30 |
| Object storage | Cloudflare R2 (sem cobrança de egresso) | Backblaze B2, AWS S3 | < US$ 5 |
| E-mail transacional | Resend ou Amazon SES | Postmark | US$ 0 a 20 |
| WhatsApp Cloud API | Conversas de autenticação e utilidade cobradas por conversa (Brasil, centavos de dólar cada) | — | US$ 5 a 30 no piloto |
| Observabilidade | Grafana Cloud free + Sentry free | Self-hosted | US$ 0 |
| Domínio e DNS | Cloudflare DNS | Route 53 | US$ 1 a 3 |

**O que a CDN precisa fazer aqui**

1. Servir fotos dos lugares (WebP, dois tamanhos) e estáticos (CSS, JS, fontes) com cache longo e compressão.
2. Opcional na fase 3: cache do HTML público da home e dos detalhes por 60 s com purge ao aprovar ou editar um lugar (LiveView conecta depois do HTML).
3. Proteção de borda: TLS, HTTP/3, rate limit básico e WAF contra bots nos endpoints de código e relato.
4. PoP no Brasil: latência de fotos para BH é o que o freguês sente.

**Candidatas e critérios**

| CDN | Egresso aproximado (América do Sul) | PoP no Brasil | Prós | Contras | Encaixe |
| --- | --- | --- | --- | --- | --- |
| Cloudflare (Free/Pro) | Incluído no plano; Pro \~US$ 20–25/mês | Sim (São Paulo, Rio, outras) | DNS, WAF, rate limit e R2 integrados; egresso de R2 grátis; melhor custo | Cache de HTML exige regras cuidadosas com websocket do LiveView; Free tem limites de regras | Favorita para o piloto |
| Bunny.net | \~US$ 0,03/GB em volume (São Paulo) | Sim | Simples, barato, otimizador de imagem embutido | Sem WAF robusto; storage próprio separado do R2 | Boa para só fotos |
| AWS CloudFront | \~US$ 0,11/GB após o free tier (1 TB/mês) | Sim (São Paulo, Rio) | Integra com S3 e WAF | Mais caro por GB e por requisição; mais configuração | Só se a stack migrar para AWS |
| Fastly | A partir de \~US$ 50/mês | Sim | Purge instantâneo, ótimo para HTML | Preço alto para o volume do piloto | Fase 3 se o cache de HTML valer |

**Como decidir (no fim da fase 1)**: medir 30 dias de produção sem CDN: GB servidos de fotos, p75 de LCP em 4G em BH, e custo de egresso do storage. Se LCP > 2,5 s ou o egresso passar de \~100 GB/mês, ligar a CDN de fotos e estáticos (Cloudflare com R2 é o caminho de menor atrito); cache de HTML só se o p95 do servidor passar de 300 ms com cache de `place_stats` já ligado.

**Deploy e ambientes**

- `dev` local com Docker Compose (Postgres+PostGIS, MinIO, Mailpit, `Messaging.Fake`).
- `staging` igual à produção, com número de WhatsApp de teste e AdSense em modo teste.
- `prod` com deploy por tag via GitHub Actions: build do release, migração no boot (`Freguesia.Release.migrate`), rollout em duas máquinas.
- Variáveis: `DATABASE_URL`, `SECRET_KEY_BASE`, `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID`, `GOOGLE_CLIENT_ID/SECRET`, `S3_*`, `ADSENSE_CLIENT`, `SENTRY_DSN`.

## 16. Roadmap e critérios de pronto

São 18 semanas em quatro fases; cada portão é um critério medido, não uma data. A CDN é decidida e ligada na fase 3, com dados de produção em mãos.

&#91;embedded content: roadmap · 4 fases, 3 portões\]

O piloto (fase 1) é a aposta: só segue para conta e promoções quando houver 40 lugares verificados e 25% de resposta ao retorno do WhatsApp.

**Entregas por fase**

| Fase | Entregas | Portão de saída |
| --- | --- | --- |
| 0 · Fundação | Repositório, CI, Docker Compose, `phx.gen.auth` para admins, migrações da seção 9, tokens do design system e componentes base, seeds com bairros e 6 lugares fictícios, deploy em staging | G1: fluxo cadastro → código (fake) → aprovação → card no ar rodando em staging |
| 1 · Piloto | Inicial, localização, home, detalhes, retorno e relatos, `place_stats`, cadastro em 3 passos com WhatsApp real, backoffice (verificações, lugares, denúncias), páginas legais, PWA, observabilidade; lançamento na Savassi com 15 lugares convidados | G2: 40 verificados nos 5 bairros e 25% de resposta por 2 semanas seguidas |
| 2 · Conta | Entrar com Google e e-mail, favoritos sincronizados, perfil e exclusão de conta, busca com histórico, aba Promoções (grátis), moderação de promoções, AdSense nos dois slots, peso de relato por conta | G3: média de economia exibida em 50% dos verificados; receita de AdSense medida |
| 3 · Receita | Promoções pagas e anúncio próprio (pagamento por Pix via gateway), painel do restaurante com login por WhatsApp, decisão e implantação da CDN, cache de HTML se necessário, segunda cidade em avaliação | Primeiros 10 lugares pagantes e custo de infra < 15% da receita |

**Definição de pronto (toda história)**: testes passando no CI; sem regressão de acessibilidade (axe no Wallaby); copy revisada contra as regras da seção 4; evento de produto emitido; métrica ou log para operar; deploy em staging validado no celular.

## 17. Riscos, dependências e perguntas abertas

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Meta rejeitar templates ou limitar o número da Freguesia | Cadastro trava | Templates submetidos na fase 0; fallback de verificação por ligação do operador registrada no backoffice |
| Poucos relatos por lugar (loop não fecha) | Sem média de economia, pilar 3 não aparece | Retorno automático ao voltar do WhatsApp, pergunta de um toque, "Responder depois"; convite em favoritos |
| Relatos fraudulentos (restaurante inflando a própria média) | Perda de confiança | Limites por dispositivo, peso por conta, lote suspeito em revisão, média só com 10+ |
| Reclamação de apps de entrega ou de restaurantes sobre comparações | Jurídico | Regras da seção 4 no código (testes de copy), economia sempre atribuída, nunca marca de concorrente |
| Golpes com números falsos | Dano ao freguês e à marca | Só verificados mostram oferta e foto; aviso de Pix; denúncia esconde o botão em 2 casos |
| Um único operador no backoffice | Fila cresce, aprovação lenta | Meta de 4 h úteis; mensagem ao restaurante com prazo; checagens automáticas reduzem o trabalho |
| Custo da WhatsApp API crescer com volume | Margem | Mensagens só transacionais; sem marketing por WhatsApp |
| Dependência de AdSense para receita inicial | Receita baixa e volátil | Promoções pagas e anúncio próprio na fase 3 como receita principal |

**Dependências externas**: conta WhatsApp Business verificada pela Meta; projeto no Google Cloud para OAuth e conta AdSense aprovada (exige domínio no ar com conteúdo); CNPJ e termos revisados por advogado antes do lançamento.

**Perguntas abertas**

- [ ] A verificação exige CNPJ ou basta o número de WhatsApp Business? (proposta: só o número no piloto)
- [ ] Restaurante que atende por WhatsApp mas também está nos apps entra normalmente? (proposta: sim; o produto não julga)
- [ ] Faixas de economia ficam em percentual ou passamos a perguntar o valor em reais na fase 2?
- [ ] Promoção paga por publicação ou assinatura mensal? Preço alvo?
- [ ] Segunda cidade: Contagem/Nova Lima (vizinhas) ou outra capital?
- [ ] Nome e domínio definitivos (freguesia.app, pededireto.com.br)?
- [ ] Fotos: o restaurante sobe a própria ou a Freguesia fotografa nos primeiros 40?
