defmodule Freguesia.ReportsTest do
  use Freguesia.DataCase, async: true

  import Ecto.Query, warn: false

  alias Freguesia.{Fixtures, Repo, Reports}
  alias Freguesia.Reports.{Antifraud, Complaint, Open, Report}

  @now ~U[2026-10-12 15:00:00Z]
  @device "11111111-1111-7111-8111-111111111111"
  @ip Antifraud.ip24_hash("10.1.2")

  defp ctx(overrides \\ %{}) do
    Map.merge(%{device_id: @device, ip24_hash: @ip}, overrides)
  end

  defp open!(place, opts \\ []) do
    at = Keyword.get(opts, :at, @now)
    device = Keyword.get(opts, :device, @device)
    {:ok, open} = Reports.open_whatsapp(place.id, device, at)
    open
  end

  setup do
    %{place: Fixtures.verified_place()}
  end

  describe "abertura pendente" do
    test "vale até 2 horas depois do clique", %{place: place} do
      open = open!(place, at: DateTime.add(@now, -2 * 3600 + 1))
      assert Reports.pending_open(place.id, @device, @now).id == open.id
    end

    test "some depois de 2 horas", %{place: place} do
      open!(place, at: DateTime.add(@now, -2 * 3600 - 1))
      assert Reports.pending_open(place.id, @device, @now) == nil
    end

    test "é de um dispositivo só", %{place: place} do
      open!(place)
      assert Reports.pending_open(place.id, "22222222-2222-7222-8222-222222222222", @now) == nil
    end

    test "some depois de respondida", %{place: place} do
      open = open!(place)
      {:ok, _} = Reports.answer(open.id, %{outcome: :worked, band: "le10"}, ctx(), @now)
      assert Reports.pending_open(place.id, @device, @now) == nil
    end
  end

  describe "answer/4" do
    test "sim com faixa grava relato válido e marca a abertura", %{place: place} do
      open = open!(place)

      assert {:ok, report} =
               Reports.answer(open.id, %{outcome: :worked, band: "le20"}, ctx(), @now)

      assert report.outcome == :worked
      assert report.savings_band == "le20"
      assert report.valid
      assert Repo.get!(Open, open.id).responded_at == @now
    end

    test "uma resposta por abertura", %{place: place} do
      open = open!(place)
      {:ok, _} = Reports.answer(open.id, %{outcome: :worked, band: "none"}, ctx(), @now)

      assert {:error, :already_answered} =
               Reports.answer(open.id, %{outcome: :failed, reason: :no_answer}, ctx(), @now)
    end

    test "resposta depois de 2 horas é recusada", %{place: place} do
      open = open!(place, at: DateTime.add(@now, -2 * 3600 - 1))

      assert {:error, :expired} =
               Reports.answer(open.id, %{outcome: :worked, band: "none"}, ctx(), @now)
    end

    test "faixa inválida é recusada", %{place: place} do
      open = open!(place)

      assert {:error, :invalid_band} =
               Reports.answer(open.id, %{outcome: :worked, band: "gigante"}, ctx(), @now)
    end

    test "motivo de falha inválido é recusado", %{place: place} do
      open = open!(place)

      assert {:error, :invalid_reason} =
               Reports.answer(open.id, %{outcome: :failed, reason: :qualquer}, ctx(), @now)
    end

    test "não comparei é válido e não tem faixa de média", %{place: place} do
      open = open!(place)

      assert {:ok, report} =
               Reports.answer(open.id, %{outcome: :worked, band: "not_compared"}, ctx(), @now)

      assert report.savings_band == "not_compared"
    end

    test "não funcionou grava o motivo", %{place: place} do
      open = open!(place)

      assert {:ok, report} =
               Reports.answer(open.id, %{outcome: :failed, reason: :app_only}, ctx(), @now)

      assert report.outcome == :failed
      assert report.fail_reason == :app_only
      assert report.savings_band == nil
    end
  end

  describe "denúncia" do
    test "número errado ou golpe conta como não e abre caso", %{place: place} do
      open = open!(place)

      assert {:ok, report} =
               Reports.answer(open.id, %{outcome: :failed, reason: :wrong_or_scam}, ctx(), @now)

      assert report.fail_reason == :wrong_or_scam
      assert Repo.aggregate(from(c in Complaint, where: c.place_id == ^place.id), :count) == 1
    end

    test "duas denúncias em 7 dias escondem o WhatsApp", %{place: place} do
      refute Reports.whatsapp_hidden?(place.id, @now)

      for i <- 1..2 do
        device = "3333333#{i}-3333-7333-8333-333333333333"
        open = open!(place, device: device)

        {:ok, _} =
          Reports.answer(
            open.id,
            %{outcome: :failed, reason: :wrong_or_scam},
            ctx(%{device_id: device, ip24_hash: nil}),
            @now
          )
      end

      assert Reports.whatsapp_hidden?(place.id, @now)
    end

    test "denúncias antigas, de mais de 7 dias, não contam", %{place: place} do
      Repo.insert!(%Complaint{
        place_id: place.id,
        source: :report,
        reason: :wrong_or_scam,
        status: :open,
        inserted_at: DateTime.add(@now, -8 * 86_400),
        updated_at: @now
      })

      Repo.insert!(%Complaint{
        place_id: place.id,
        source: :report,
        reason: :wrong_or_scam,
        status: :open,
        inserted_at: @now,
        updated_at: @now
      })

      refute Reports.whatsapp_hidden?(place.id, @now)
    end

    test "denúncia fechada pelo operador deixa de contar", %{place: place} do
      for _ <- 1..2 do
        Repo.insert!(%Complaint{
          place_id: place.id,
          source: :report,
          reason: :wrong_or_scam,
          status: :closed,
          inserted_at: @now,
          updated_at: @now
        })
      end

      refute Reports.whatsapp_hidden?(place.id, @now)
    end
  end

  describe "antifraude" do
    test "o 4º relato válido do mesmo dispositivo no mesmo lugar em 30 dias é inválido", %{
      place: place
    } do
      reports =
        for _ <- 1..4 do
          open = open!(place)

          {:ok, report} =
            Reports.answer(
              open.id,
              %{outcome: :worked, band: "le10"},
              ctx(%{ip24_hash: nil}),
              @now
            )

          report
        end

      assert Enum.map(reports, & &1.valid) == [true, true, true, false]
      assert List.last(reports).invalid_reason == "device_limit"
    end

    test "lote de mais de 10 relatos do mesmo /24 em 1 hora fica em revisão", %{place: place} do
      reports =
        for i <- 1..11 do
          device =
            "4444444#{rem(i, 10)}-4444-7444-8444-44444444444#{rem(i, 10)}"
            |> then(&if(i == 10, do: "44444444-4444-7444-8444-444444444440", else: &1))

          open = open!(place, device: device)

          {:ok, report} =
            Reports.answer(
              open.id,
              %{outcome: :worked, band: "le10"},
              ctx(%{device_id: device}),
              @now
            )

          report
        end

      {valid, [batch]} = Enum.split(reports, 10)
      assert Enum.all?(valid, & &1.valid)
      refute batch.valid
      assert batch.invalid_reason == "batch_review"
    end

    test "relatos de /24 diferentes não formam lote" do
      assert Antifraud.ip24_hash_from_text("10.1.2.3") ==
               Antifraud.ip24_hash_from_text("10.1.2.200")

      refute Antifraud.ip24_hash_from_text("10.1.2.3") ==
               Antifraud.ip24_hash_from_text("10.1.3.3")
    end

    test "IPv6 não gera hash de /24" do
      assert Antifraud.ip24_hash_from_text("::1") == nil
      assert Antifraud.ip24_hash_from_text(nil) == nil
    end

    test "purga apaga o hash de relatos com mais de 30 dias", %{place: place} do
      old = open!(place, at: DateTime.add(@now, -31 * 86_400))

      {:ok, _} =
        Reports.answer(
          old.id,
          %{outcome: :worked, band: "le10"},
          ctx(),
          DateTime.add(@now, -31 * 86_400)
        )

      recent = open!(place, device: "55555555-5555-7555-8555-555555555555")

      {:ok, _} =
        Reports.answer(
          recent.id,
          %{outcome: :worked, band: "le10"},
          ctx(%{device_id: "55555555-5555-7555-8555-555555555555"}),
          @now
        )

      assert Reports.purge_ip_hashes(@now) == 1
      assert Repo.aggregate(from(r in Report, where: not is_nil(r.ip24_hash)), :count) == 1
    end
  end
end
