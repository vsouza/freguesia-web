defmodule Freguesia.DeliveryAreasTest do
  use Freguesia.DataCase, async: true

  import Ecto.Query

  alias Freguesia.{Catalog, DeliveryAreas, Fixtures, Repo}
  alias Freguesia.Catalog.{Place, PlaceCoverage}

  # Centroid of the test polygon for Savassi (see Fixtures.reference_data!/0).
  @centroid {-19.9372, -43.9378}
  # About 3.2 km east of the centroid: past the 3 km default radius.
  @beyond {-19.9372, -43.9078}

  setup do
    savassi = Fixtures.neighborhood()
    place = Fixtures.verified_place(%{name: "Area Teste", neighborhood: savassi})
    %{savassi: savassi, place: place}
  end

  describe "default area" do
    test "is created with a 3 km radius, and the point starts at the neighborhood centroid", %{
      place: place
    } do
      area = DeliveryAreas.get_for_place(place.id)

      assert area.radius_m == 3000
      assert area.exclusions == []
      assert DeliveryAreas.default_radius_m() == 3000
      {lat, lng} = Catalog.home_point(place.neighborhood, nil)
      assert_in_delta lat, elem(@centroid, 0), 1.0e-9
      assert_in_delta lng, elem(@centroid, 1), 1.0e-9
    end

    test "covers the place's own neighborhood in the derived coverage", %{
      place: place,
      savassi: savassi
    } do
      assert Repo.exists?(
               from c in PlaceCoverage,
                 where: c.place_id == ^place.id and c.neighborhood_id == ^savassi.id
             )
    end
  end

  describe "save/3" do
    test "removing a neighborhood hides the place from points inside it", %{
      place: place,
      savassi: savassi
    } do
      assert [_] = Catalog.list_home_places(savassi, @centroid)

      {:ok, area} = DeliveryAreas.save(place.id, 3000, [savassi.id])

      assert [%{neighborhood_id: _}] = area.exclusions
      assert Catalog.list_home_places(savassi, @centroid) == []
      refute Repo.exists?(from c in PlaceCoverage, where: c.place_id == ^place.id)
    end

    test "a wider radius reaches points beyond the default", %{place: place, savassi: savassi} do
      assert Catalog.list_home_places(savassi, @beyond) == []

      {:ok, area} = DeliveryAreas.save(place.id, 4000, [])

      assert area.radius_m == 4000
      assert [_] = Catalog.list_home_places(savassi, @beyond)
    end

    test "radius must be between 500 and 6000 metres, in steps of 500", %{place: place} do
      assert {:error, changeset} = DeliveryAreas.save(place.id, 400, [])
      assert %{radius_m: [_ | _]} = errors_on(changeset)

      assert {:error, changeset} = DeliveryAreas.save(place.id, 6500, [])
      assert %{radius_m: [_ | _]} = errors_on(changeset)

      assert {:error, changeset} = DeliveryAreas.save(place.id, 3250, [])
      assert %{radius_m: [_ | _]} = errors_on(changeset)
    end
  end

  describe "set_point/3" do
    test "moves the point inside a pilot neighborhood and keeps the coverage derived", %{
      place: place,
      savassi: savassi
    } do
      # Inside the Savassi polygon, away from the centroid.
      assert {:ok, {-19.938, -43.939}} = DeliveryAreas.set_point(place.id, -19.938, -43.939)

      assert DeliveryAreas.point_of(place.id) == {-19.938, -43.939}
      assert [_] = Catalog.list_home_places(savassi, {-19.938, -43.939})
    end

    test "refuses a point outside the pilot neighborhoods and leaves the place alone", %{
      place: place
    } do
      before = DeliveryAreas.point_of(place.id)

      assert {:error, :outside_pilot} = DeliveryAreas.set_point(place.id, -20.5, -44.5)
      assert DeliveryAreas.point_of(place.id) == before
    end

    test "refuses values that are not numbers" do
      assert {:error, :invalid_point} = DeliveryAreas.set_point(Ecto.UUID.generate(), "x", nil)
    end
  end

  describe "neighborhood_distances/1" do
    test "lists pilot neighborhoods nearest first, with the distance from the point", %{
      place: place,
      savassi: savassi
    } do
      [nearest | _] = DeliveryAreas.neighborhood_distances(place.id)

      assert nearest.id == savassi.id
      assert nearest.distance_m == 0
    end
  end

  describe "covering_place_ids_query/2" do
    test "ignores places that are not verified", %{place: place} do
      Repo.update_all(from(p in Place, where: p.id == ^place.id), set: [status: :pending])

      {lat, lng} = @centroid
      ids = Repo.all(DeliveryAreas.covering_place_ids_query(lat, lng))

      refute place.id in ids
    end
  end
end
