defmodule Freguesia.Fixtures do
  @moduledoc """
  Dados de teste do domínio. Cada função cria o que falta e devolve o registro.
  """
  alias Freguesia.{Admin, Repo}
  alias Freguesia.Catalog.{Category, City, Neighborhood, Place, PlaceCoverage, Segment, Text}

  @password "senha-de-teste-123456"

  def password, do: @password

  @doc """
  Dados de referência (cidade, bairros, segmento, categoria). Criados uma vez, no
  `test_helper.exs`, com o sandbox em modo `auto`. Assim os testes assíncronos
  só leem essas linhas e não disputam chaves únicas, o que causava deadlock.
  """
  def reference_data! do
    city()
    neighborhood(%{slug: "savassi", name: "Savassi"})
    neighborhood(%{slug: "lourdes", name: "Lourdes"})
    neighborhood(%{slug: "centro", name: "Centro", pilot: false})
    restaurants()
    category("pizza")
    :ok
  end

  def city do
    get_or_insert(City, %{slug: "belo-horizonte"}, %{
      name: "Belo Horizonte",
      state: "MG",
      active: true
    })
  end

  def neighborhood(attrs \\ %{}) do
    city = city()
    slug = Map.get(attrs, :slug, "savassi")

    get_or_insert(Neighborhood, %{city_id: city.id, slug: slug}, %{
      name: Map.get(attrs, :name, "Savassi"),
      pilot: Map.get(attrs, :pilot, true)
    })
  end

  def restaurants do
    get_or_insert(Segment, %{key: "restaurants"}, %{name: "Restaurantes", color_key: "pessego"})
  end

  def category(key \\ "pizza") do
    get_or_insert(Category, %{segment_id: restaurants().id, key: key}, %{
      name: String.capitalize(key),
      color_key: "tomate"
    })
  end

  def operator(attrs \\ %{}) do
    email = Map.get(attrs, :email, "op#{System.unique_integer([:positive])}@freguesia.test")

    {:ok, operator} =
      Admin.create_operator(%{
        email: email,
        password: @password,
        role: Map.get(attrs, :role, :admin)
      })

    operator
  end

  @doc "Horário aberto todo dia, das 11h às 22h (em minutos)."
  def all_day_hours do
    interval = [[660, 1320]]

    %{
      "mon" => interval,
      "tue" => interval,
      "wed" => interval,
      "thu" => interval,
      "fri" => interval,
      "sat" => interval,
      "sun" => interval
    }
  end

  @doc "Lugar já verificado, com cobertura no próprio bairro."
  def verified_place(attrs \\ %{}) do
    neighborhood = Map.get_lazy(attrs, :neighborhood, fn -> neighborhood() end)
    name = Map.get(attrs, :name, "Pizzaria Teste #{System.unique_integer([:positive])}")

    place =
      Repo.insert!(%Place{
        name: name,
        slug:
          Map.get(
            attrs,
            :slug,
            Text.slugify(name) <> "-#{System.unique_integer([:positive])}"
          ),
        segment_id: restaurants().id,
        category_id: category().id,
        neighborhood_id: neighborhood.id,
        whatsapp_e164:
          Map.get_lazy(attrs, :whatsapp_e164, fn ->
            "+55" <> String.replace(unique_whatsapp(), ~r/\D/, "")
          end),
        status: :verified,
        delivery_mode: :own,
        opening_hours: Map.get(attrs, :opening_hours, all_day_hours()),
        verified_at: now(),
        paused_until: Map.get(attrs, :paused_until)
      })

    Repo.insert_all(PlaceCoverage, [
      %{
        place_id: place.id,
        neighborhood_id: neighborhood.id,
        inserted_at: now(),
        updated_at: now()
      }
    ])

    Repo.preload(place, [:neighborhood, :segment, :category])
  end

  @doc "Parâmetros de formulário do cadastro, com a forma que o LiveView envia (chaves string)."
  def signup_params(overrides \\ %{}) do
    neighborhood = neighborhood()
    segment = restaurants()
    category = category()

    %{
      "name" => "Pizzaria do Teste",
      "segment_id" => segment.id,
      "category_id" => category.id,
      "neighborhood_id" => neighborhood.id,
      "whatsapp" => unique_whatsapp(),
      "delivery_mode" => "own",
      "coverage_ids" => [neighborhood.id],
      "offer_text" => "",
      "accept_terms" => "true"
    }
    |> Map.merge(overrides)
  end

  # Número único por chamada: o Fake de mensagens é global e os testes rodam em paralelo.
  def unique_whatsapp do
    digits =
      System.unique_integer([:positive])
      |> rem(100_000_000)
      |> Integer.to_string()
      |> String.pad_leading(8, "0")

    "(31) 9" <> digits
  end

  defp get_or_insert(schema, match, attrs) do
    case Repo.get_by(schema, match) do
      nil -> Repo.insert!(struct(schema, Map.merge(match, attrs)))
      record -> record
    end
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
