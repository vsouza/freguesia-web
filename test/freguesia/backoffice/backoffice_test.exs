defmodule Freguesia.BackofficeTest do
  use Freguesia.DataCase, async: true

  import Ecto.Query, warn: false

  alias Freguesia.{Admin, Backoffice, Fixtures, Repo}
  alias Freguesia.Admin.AuditEntry
  alias Freguesia.Catalog.{Category, Place}
  alias Freguesia.Reports.{Complaint, Report}

  setup do
    %{operator: Fixtures.operator(), place: Fixtures.verified_place(%{name: "Padaria Teste"})}
  end

  describe "pause and resume" do
    test "pausing sets paused_until to the end of today in São Paulo and is audited", %{
      place: place,
      operator: op
    } do
      assert {:ok, paused} = Backoffice.pause_today(place, op)

      assert %DateTime{} = paused.paused_until
      sp = DateTime.shift_zone!(paused.paused_until, "America/Sao_Paulo")
      assert sp.hour == 0 and sp.minute == 0
      assert DateTime.compare(paused.paused_until, DateTime.utc_now()) == :gt

      assert [entry] = Admin.audit_entries("place", place.id)
      assert entry.action == "place.pause"
      assert entry.admin_id == op.id
    end

    test "resuming clears the pause", %{place: place, operator: op} do
      {:ok, paused} = Backoffice.pause_today(place, op)
      assert {:ok, resumed} = Backoffice.resume(paused, op)
      assert resumed.paused_until == nil
    end
  end

  describe "remove" do
    test "requires a reason", %{place: place, operator: op} do
      assert {:error, :reason_required} = Backoffice.remove(place, op, "  ")
      assert Repo.get!(Place, place.id).status == :verified
    end

    test "removes the place and keeps the reason in the audit trail", %{
      place: place,
      operator: op
    } do
      assert {:ok, removed} =
               Backoffice.remove(place, op, "Restaurant asked for removal on WhatsApp")

      assert removed.status == :removed
      assert removed.removed_at

      entry = Repo.one!(from a in AuditEntry, where: a.action == "place.remove")
      assert entry.after["reason"] == "Restaurant asked for removal on WhatsApp"
    end
  end

  describe "reassign_category" do
    test "moves the place to another category of the same segment", %{place: place, operator: op} do
      other = Fixtures.category("mineira")
      assert {:ok, updated} = Backoffice.reassign_category(place, op, other.id)
      assert updated.category_id == other.id
    end

    test "refuses a category from another segment", %{place: place, operator: op} do
      other_segment =
        Repo.insert!(%Freguesia.Catalog.Segment{
          key: "pet-test",
          name: "Pet",
          color_key: "pitaya"
        })

      foreign =
        Repo.insert!(%Category{
          segment_id: other_segment.id,
          key: "food",
          name: "Food",
          color_key: "pitaya"
        })

      assert {:error, :invalid_category} = Backoffice.reassign_category(place, op, foreign.id)
    end
  end

  describe "complaints" do
    test "closing a complaint needs a resolution and stops it from hiding the button", %{
      place: place,
      operator: op
    } do
      complaint =
        Repo.insert!(%Complaint{
          place_id: place.id,
          source: :form,
          reason: :wrong_or_scam,
          status: :open,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert {:error, :reason_required} = Backoffice.close_complaint(complaint, op, "")

      assert {:ok, closed} =
               Backoffice.close_complaint(complaint, op, "Number checked, it is correct")

      assert closed.status == :closed
      assert Backoffice.list_complaints() == []
    end
  end

  describe "batch review" do
    test "a held report can be released and is audited", %{place: place, operator: op} do
      open = Fixtures.open_for!(place)

      held =
        Repo.insert!(%Report{
          open_id: open.id,
          place_id: place.id,
          device_id: Ecto.UUID.generate(),
          outcome: :worked,
          savings_band: "le10",
          valid: false,
          invalid_reason: "batch_review",
          weight: Decimal.new("1.0"),
          answered_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert [flagged] = Backoffice.flagged_reports(place.id)
      assert flagged.id == held.id

      assert {:ok, released} = Backoffice.release_report(held, op)
      assert released.valid
      assert released.invalid_reason == nil
      assert Backoffice.flagged_reports(place.id) == []
      assert Repo.one!(from a in AuditEntry, where: a.action == "report.release")
    end
  end

  describe "listing" do
    test "searches by name and filters by status" do
      Fixtures.verified_place(%{name: "Lanchonete Azul"})
      assert [_] = Backoffice.list_places(%{query: "azul"})
      assert [] = Backoffice.list_places(%{query: "azul", status: "pending"})
    end
  end
end
