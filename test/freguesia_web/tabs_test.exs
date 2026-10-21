defmodule FreguesiaWeb.TabsTest do
  use FreguesiaWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Freguesia.Catalog.Promotion
  alias Freguesia.{Fixtures, Repo}

  defp promotion!(place, attrs) do
    Repo.insert!(
      struct(
        Promotion,
        Map.merge(
          %{
            place_id: place.id,
            title: "Promo #{System.unique_integer([:positive])}",
            status: :approved,
            starts_at: DateTime.add(DateTime.utc_now(), -86_400) |> DateTime.truncate(:second),
            ends_at: DateTime.add(DateTime.utc_now(), 86_400) |> DateTime.truncate(:second)
          },
          attrs
        )
      )
    )
  end

  describe "promotions tab" do
    test "shows an empty state when nothing is running", %{conn: conn} do
      html = conn |> get(~p"/promotions") |> html_response(200)
      assert html =~ ~s(id="no-promotions")
    end

    test "lists approved promotions that are running, not pending or expired", %{conn: conn} do
      place = Fixtures.verified_place(%{name: "Com Promo"})
      running = promotion!(place, %{title: "Sobremesa grátis"})
      _pending = promotion!(place, %{status: :pending})
      expired = promotion!(place, %{ends_at: ~U[2020-01-01 00:00:00Z]})

      html = conn |> get(~p"/promotions") |> html_response(200)

      assert html =~ ~s(id="promotion-#{running.id}")
      refute html =~ ~s(id="promotion-#{expired.id}")
      refute html =~ ~s(id="no-promotions")
    end
  end

  describe "favorites tab" do
    test "shows the saved places that are still verified, and drops the rest", %{conn: conn} do
      kept = Fixtures.verified_place(%{name: "Guardado"})
      pending = Fixtures.verified_place(%{name: "Pendente"})

      Repo.update_all(from(p in Freguesia.Catalog.Place, where: p.id == ^pending.id),
        set: [status: :pending]
      )

      {:ok, view, _html} = live(conn, ~p"/favorites")
      assert has_element?(view, "#favorites-empty")

      render_hook(view, "load", %{"slugs" => [kept.slug, pending.slug, "nao-existe"]})

      assert has_element?(view, "#place-card-#{kept.slug}")
      refute has_element?(view, "#place-card-#{pending.slug}")
      refute has_element?(view, "#favorites-empty")
    end

    test "garbage in the saved list does not crash the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/favorites")
      render_hook(view, "load", %{"slugs" => [1, nil, %{}]})
      assert has_element?(view, "#favorite-places")
    end
  end

  test "how it works explains the three steps", %{conn: conn} do
    html = conn |> get(~p"/how-it-works") |> html_response(200)
    assert html =~ ~s(id="how-steps")
  end

  test "profile says accounts are not open yet and links to the business sign-in", %{conn: conn} do
    conn = get(conn, ~p"/profile")
    html = html_response(conn, 200)

    assert html =~ ~s(id="profile-guest")
    assert html =~ ~s(href="/business/sign-in")
  end

  test "the bottom bar has five tabs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/areas/savassi")

    for path <- ["/areas/savassi", "/search", "/promotions", "/favorites", "/profile"] do
      assert has_element?(view, ~s(nav[aria-label="Principal"].fixed a[href="#{path}"]))
    end
  end
end
