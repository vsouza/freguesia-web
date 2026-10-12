# Dados de desenvolvimento. Rodar de novo não duplica nada:
#
#     mix run priv/repo/seeds.exs
#
# - Cidade e 5 bairros do piloto (polígonos APROXIMADOS, só para dev)
# - Segmentos e categorias
# - 6 lugares fictícios verificados (nomes provisórios, trocar pelos do canvas)
# - 1 pedido pendente, para a fila não começar vazia
# - 1 operador admin de dev (2FA é cadastrado no primeiro login)
# - Slots de anúncio, desligados

import Ecto.Query

alias Freguesia.Repo
alias Freguesia.Admin
alias Freguesia.Admin.Operator
alias Freguesia.Catalog.{Category, City, Neighborhood, Offer, Place, PlaceCoverage, Segment}
alias Freguesia.Verification.Request

now = DateTime.utc_now() |> DateTime.truncate(:second)

# --- Cidade e bairros do piloto -------------------------------------------

city =
  Repo.insert!(
    %City{name: "Belo Horizonte", slug: "belo-horizonte", state: "MG", active: true},
    on_conflict: :nothing,
    conflict_target: [:slug]
  )

city = Repo.get_by!(City, slug: city.slug)

# Centro aproximado e um quadrado de ~600 m em volta. Não são os limites oficiais.
pilot_neighborhoods = [
  {"Savassi", "savassi", -43.9378, -19.9372},
  {"Lourdes", "lourdes", -43.9400, -19.9330},
  {"Funcionários", "funcionarios", -43.9450, -19.9290},
  {"Santa Tereza", "santa-tereza", -43.9240, -19.9230},
  {"Sion", "sion", -43.9580, -19.9440}
]

for {name, slug, lng, lat} <- pilot_neighborhoods do
  d = 0.003

  wkt =
    "POLYGON((#{lng - d} #{lat - d}, #{lng + d} #{lat - d}, #{lng + d} #{lat + d}, #{lng - d} #{lat + d}, #{lng - d} #{lat - d}))"

  Repo.query!(
    """
    INSERT INTO neighborhoods (id, city_id, name, slug, geom, pilot, inserted_at, updated_at)
    VALUES (gen_random_uuid(), $1, $2, $3, ST_GeomFromText($4, 4326), true, $5, $5)
    ON CONFLICT (city_id, slug) DO UPDATE SET pilot = true, geom = EXCLUDED.geom
    """,
    [Ecto.UUID.dump!(city.id), name, slug, wkt, now]
  )
end

neighborhood = fn slug -> Repo.get_by!(Neighborhood, slug: slug) end

# --- Segmentos e categorias -----------------------------------------------

segments = [
  {"restaurants", "Restaurantes", "pessego"},
  {"pharmacies", "Farmácias", "agua"},
  {"markets", "Mercados", "laranja"},
  {"construction", "Construção", "concreto"},
  {"pet", "Pet", "pitaya"}
]

for {key, name, color} <- segments do
  Repo.insert!(%Segment{key: key, name: name, color_key: color},
    on_conflict: :nothing,
    conflict_target: [:key]
  )
end

restaurants = Repo.get_by!(Segment, key: "restaurants")

categories = [
  {"pizza", "Pizza", "tomate"},
  {"mineira", "Mineira", "milho"},
  {"burger", "Hambúrguer", "cacau"},
  {"italian", "Italiana", "vinho"},
  {"japanese", "Japonesa", "indigo"},
  {"acai", "Açaí", "uva"}
]

for {key, name, color} <- categories do
  Repo.insert!(
    %Category{segment_id: restaurants.id, key: key, name: name, color_key: color},
    on_conflict: :nothing,
    conflict_target: [:segment_id, :key]
  )
end

category = fn key -> Repo.get_by!(Category, segment_id: restaurants.id, key: key) end

# --- Lugares fictícios verificados ----------------------------------------

weekday = fn open, close -> [[open, close]] end

week_hours = %{
  "mon" => weekday.(660, 1320),
  "tue" => weekday.(660, 1320),
  "wed" => weekday.(660, 1320),
  "thu" => weekday.(660, 1320),
  "fri" => weekday.(660, 1380),
  "sat" => weekday.(660, 1380),
  "sun" => weekday.(720, 1200)
}

# {nome, slug, categoria, bairro, WhatsApp E.164, oferta (texto, resumo ou nil), bairros atendidos}
fictional_places = [
  {"Pizzaria do Largo", "pizzaria-do-largo", "pizza", "savassi", "+5531900000001",
   {"10% de desconto no pedido direto", "10% off"}, ["savassi", "lourdes"]},
  {"Mineira da Dona Lúcia", "mineira-dona-lucia", "mineira", "lourdes", "+5531900000002", nil,
   ["lourdes", "savassi"]},
  {"Burger do Cacau", "burger-do-cacau", "burger", "santa-tereza", "+5531900000003",
   {"Batata grátis no combo", "Batata grátis"}, ["santa-tereza"]},
  {"Trattoria Vinho Tinto", "trattoria-vinho-tinto", "italian", "savassi", "+5531900000004",
   {"Sobremesa da casa no pedido direto", "Sobremesa"}, ["savassi", "funcionarios"]},
  {"Sushi da Praça", "sushi-da-praca", "japanese", "funcionarios", "+5531900000005", nil,
   ["funcionarios"]},
  {"Açaí da Serra", "acai-da-serra", "acai", "sion", "+5531900000006",
   {"15% off acima de R$ 30", "15% off"}, ["sion", "santa-tereza"]}
]

for {name, slug, cat_key, hood_slug, whatsapp, offer, coverage_slugs} <- fictional_places do
  unless Repo.get_by(Place, slug: slug) do
    place =
      Repo.insert!(%Place{
        name: name,
        slug: slug,
        segment_id: restaurants.id,
        category_id: category.(cat_key).id,
        neighborhood_id: neighborhood.(hood_slug).id,
        whatsapp_e164: whatsapp,
        status: :verified,
        delivery_mode: :own,
        opening_hours: week_hours,
        verified_at: now,
        terms_accepted_at: now
      })

    for coverage_slug <- Enum.uniq(coverage_slugs) do
      Repo.insert_all(PlaceCoverage, [
        %{
          place_id: place.id,
          neighborhood_id: neighborhood.(coverage_slug).id,
          inserted_at: now,
          updated_at: now
        }
      ])
    end

    case offer do
      {text, tag} ->
        Repo.insert!(%Offer{
          place_id: place.id,
          text: text,
          tag: tag,
          status: :approved,
          updated_by_place_at: now,
          approved_at: now
        })

      nil ->
        :ok
    end
  end
end

# --- Pedido pendente na fila ----------------------------------------------

pending_slug = "padaria-do-bairro-dev"

unless Repo.get_by(Place, slug: pending_slug) do
  pending =
    Repo.insert!(%Place{
      name: "Padaria do Bairro",
      slug: pending_slug,
      segment_id: restaurants.id,
      category_id: category.("burger").id,
      neighborhood_id: neighborhood.("lourdes").id,
      whatsapp_e164: "+5531900000007",
      status: :pending,
      delivery_mode: :own,
      opening_hours: week_hours,
      terms_accepted_at: now
    })

  Repo.insert_all(PlaceCoverage, [
    %{
      place_id: pending.id,
      neighborhood_id: neighborhood.("lourdes").id,
      inserted_at: now,
      updated_at: now
    }
  ])

  Repo.insert!(%Request{place_id: pending.id, status: :pending, checks: %{}})
end

# --- Operador de dev ------------------------------------------------------

dev_email = "admin@freguesia.local"

unless Repo.get_by(Operator, email: dev_email) do
  {:ok, _operator} =
    Admin.create_operator(%{
      email: dev_email,
      password: "senha-dev-freguesia-2026",
      role: :admin
    })

  IO.puts("""
  Operador de dev criado:
    e-mail: #{dev_email}
    senha:  senha-dev-freguesia-2026
    O 2FA é cadastrado no primeiro login em /admin/entrar.
  """)
end

# --- Slots de anúncio (desligados) ----------------------------------------

now_naive = now

for key <- ~w(home_after_2 detail_before_about) do
  Repo.query!(
    """
    INSERT INTO ad_slots (id, key, network, enabled, blocked_categories, inserted_at, updated_at)
    VALUES (gen_random_uuid(), $1, 'adsense', false, '{}', $2, $2)
    ON CONFLICT (key) DO NOTHING
    """,
    [key, now_naive]
  )
end

IO.puts(
  "Seeds OK: #{Repo.aggregate(Place, :count)} lugares, #{Repo.aggregate(Neighborhood, :count)} bairros."
)
