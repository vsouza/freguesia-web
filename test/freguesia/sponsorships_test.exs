defmodule Freguesia.SponsorshipsTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.Admin.AuditEntry
  alias Freguesia.Catalog.{Promotion, Sponsorship}
  alias Freguesia.{Fixtures, Repo, Sponsorships}

  @now ~U[2026-10-13 15:00:00Z]

  setup do
    place = Fixtures.verified_place(%{name: "Com Anúncio"})
    %{place: place, operator: Fixtures.operator()}
  end

  defp request!(place, attrs \\ %{}, now \\ @now) do
    {:ok, sponsorship} =
      Sponsorships.request_own_ad(
        place,
        Map.merge(
          %{"title" => "Sobremesa grátis", "body" => "Na compra de dois", "days" => "3"},
          attrs
        ),
        now
      )

    sponsorship
  end

  describe "request_own_ad/3" do
    test "creates a pending promotion and a pending own placement for the place", %{place: place} do
      sponsorship = request!(place)

      assert sponsorship.status == :pending
      assert sponsorship.kind == :own_detail
      assert sponsorship.neighborhood_ids == [place.neighborhood_id]

      promotion = Repo.get!(Promotion, sponsorship.promotion_id)
      assert promotion.status == :pending
      assert promotion.title == "Sobremesa grátis"
      assert DateTime.diff(promotion.ends_at, promotion.starts_at, :second) == 3 * 86_400
    end

    test "refuses a title that is too short, a period over 7 days and a long body", %{
      place: place
    } do
      assert {:error, errors} =
               Sponsorships.request_own_ad(place, %{"title" => "ab", "days" => "8"}, @now)

      assert Keyword.has_key?(errors, :title)
      assert Keyword.has_key?(errors, :days)

      long = String.duplicate("x", 281)

      assert {:error, [body: _]} =
               Sponsorships.request_own_ad(
                 place,
                 %{"title" => "Valido", "body" => long, "days" => "1"},
                 @now
               )
    end

    test "nothing is stored when the request is refused", %{place: place} do
      before = Repo.aggregate(Sponsorship, :count)
      {:error, _} = Sponsorships.request_own_ad(place, %{"title" => "", "days" => "1"}, @now)
      assert Repo.aggregate(Sponsorship, :count) == before
    end
  end

  describe "moderation" do
    test "approving publishes the placement and its promotion together, and is audited", %{
      place: place,
      operator: operator
    } do
      sponsorship = request!(place)

      assert {:ok, :approved} = Sponsorships.approve(sponsorship.id, operator)

      assert Repo.get!(Sponsorship, sponsorship.id).status == :approved
      assert Repo.get!(Promotion, sponsorship.promotion_id).status == :approved
      assert Repo.exists?(from a in AuditEntry, where: a.action == "sponsorship.approved")
    end

    test "approving twice is harmless", %{place: place, operator: operator} do
      sponsorship = request!(place)
      {:ok, :approved} = Sponsorships.approve(sponsorship.id, operator)
      assert {:ok, :already_decided} = Sponsorships.approve(sponsorship.id, operator)
    end

    test "rejecting needs a reason and closes both rows", %{place: place, operator: operator} do
      sponsorship = request!(place)

      assert {:error, :reason_required} = Sponsorships.reject(sponsorship.id, operator, "  ")

      assert {:ok, :rejected} =
               Sponsorships.reject(sponsorship.id, operator, "Texto de comparação de preço")

      assert Repo.get!(Sponsorship, sponsorship.id).status == :rejected
      assert Repo.get!(Promotion, sponsorship.promotion_id).status == :rejected
    end

    test "a rejected ad cannot be approved later", %{place: place, operator: operator} do
      sponsorship = request!(place)
      {:ok, :rejected} = Sponsorships.reject(sponsorship.id, operator, "Não")
      assert {:error, :already_decided} = Sponsorships.approve(sponsorship.id, operator)
    end
  end

  describe "own_detail_for/2" do
    test "returns only an approved ad that is running now", %{place: place, operator: operator} do
      sponsorship = request!(place, %{}, @now)
      {:ok, :approved} = Sponsorships.approve(sponsorship.id, operator)

      assert %{id: id} = Sponsorships.own_detail_for(place.id, @now)
      assert id == sponsorship.id

      # Two days later: still inside 3 days. Four days later: expired.
      assert Sponsorships.own_detail_for(place.id, DateTime.add(@now, 2 * 86_400, :second))
      assert Sponsorships.own_detail_for(place.id, DateTime.add(@now, 4 * 86_400, :second)) == nil
    end

    test "a pending ad is never shown", %{place: place} do
      request!(place)
      assert Sponsorships.own_detail_for(place.id, @now) == nil
    end
  end
end
