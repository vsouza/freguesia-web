defmodule Freguesia.CatalogTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.{Catalog, Fixtures, Repo}
  alias Freguesia.Catalog.Place

  # Segunda 12:00 em Brasília
  @monday_noon ~U[2026-10-12 15:00:00Z]

  describe "list_home_places/2" do
    test "mostra só verificados que atendem o bairro, abertos antes de fechados, depois pelo nome" do
      savassi = Fixtures.neighborhood()
      open_b = Fixtures.verified_place(%{name: "Bistrô B", neighborhood: savassi})
      open_a = Fixtures.verified_place(%{name: "Bistrô A", neighborhood: savassi})

      closed =
        Fixtures.verified_place(%{
          name: "Cantina Fechada",
          neighborhood: savassi,
          opening_hours: %{"sat" => [[660, 1320]]}
        })

      Fixtures.verified_place(%{
        name: "Outro Bairro",
        neighborhood: Fixtures.neighborhood(%{slug: "lourdes", name: "Lourdes"})
      })

      pending = Fixtures.verified_place(%{name: "Pendente", neighborhood: savassi})
      Repo.update_all(from_place(pending), set: [status: :pending])

      names =
        savassi
        |> Catalog.list_home_places(@monday_noon)
        |> Enum.map(& &1.name)

      assert names == ["Bistrô A", "Bistrô B", "Cantina Fechada"]
      assert open_a && open_b && closed
    end

    test "lugar que atende o bairro por cobertura aparece mesmo morando em outro" do
      savassi = Fixtures.neighborhood()
      lourdes = Fixtures.neighborhood(%{slug: "lourdes", name: "Lourdes"})
      place = Fixtures.verified_place(%{name: "Atende Lourdes", neighborhood: lourdes})

      Repo.insert_all(Freguesia.Catalog.PlaceCoverage, [
        %{place_id: place.id, neighborhood_id: savassi.id, inserted_at: now(), updated_at: now()}
      ])

      assert ["Atende Lourdes"] ==
               savassi |> Catalog.list_home_places(@monday_noon) |> Enum.map(& &1.name)
    end
  end

  describe "get_place_by_slug/2" do
    test "traz a oferta aprovada e o status de horário" do
      place = Fixtures.verified_place(%{name: "Com Oferta"})

      Repo.insert!(%Freguesia.Catalog.Offer{
        place_id: place.id,
        text: "10% no pedido direto",
        tag: "10% off",
        status: :approved,
        approved_at: now()
      })

      found = Catalog.get_place_by_slug(place.slug, @monday_noon)
      assert found.hours_status == {:open, "22h"}
      assert Catalog.active_offer(found).tag == "10% off"
    end

    test "slug inexistente devolve nil" do
      assert Catalog.get_place_by_slug("nao-existe") == nil
    end
  end

  test "bairro fora do piloto não é servido como bairro do catálogo" do
    Fixtures.neighborhood(%{slug: "centro", name: "Centro", pilot: false})
    Fixtures.neighborhood()

    assert Catalog.get_pilot_neighborhood_by_slug("centro") == nil
    assert Catalog.get_pilot_neighborhood_by_slug("savassi")
  end

  defp from_place(place) do
    import Ecto.Query
    from(p in Place, where: p.id == ^place.id)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
