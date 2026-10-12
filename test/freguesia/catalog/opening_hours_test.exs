defmodule Freguesia.Catalog.OpeningHoursTest do
  use ExUnit.Case, async: true

  alias Freguesia.Catalog.OpeningHours

  # 2026-10-12 é segunda-feira. Brasília é UTC-3, então 12:00 local = 15:00Z.
  @hours %{
    "mon" => [[660, 1320]],
    "sat" => [[660, 780], [1080, 1380]],
    "sun" => [[720, 1200]]
  }

  # Monta o horário local e converte para UTC (+3h).
  defp at_local(hour, minute, date \\ ~D[2026-10-12]) do
    {:ok, local} = NaiveDateTime.new(date.year, date.month, date.day, hour, minute, 0)
    local |> NaiveDateTime.add(3 * 3600) |> DateTime.from_naive!("Etc/UTC")
  end

  test "aberto dentro do intervalo e informa até que horas" do
    assert OpeningHours.status(@hours, nil, at_local(12, 0)) == {:open, "22h"}
  end

  test "fechado antes da abertura e informa quando abre" do
    assert OpeningHours.status(@hours, nil, at_local(9, 0)) == {:closed, "11h"}
  end

  test "fechado depois do fechamento: a próxima abertura é amanhã" do
    # Segunda 23:00: terça tem o mesmo horário das 11h
    assert OpeningHours.status(@hours, nil, at_local(23, 0)) == {:closed, "11h"}
  end

  test "sábado de manhã: intervalo de almoço fecha no meio" do
    saturday = ~D[2026-10-17]
    assert OpeningHours.status(@hours, nil, at_local(13, 0, saturday)) == {:closed, "18h"}
  end

  test "dia sem horário fica fechado e sem próxima abertura na semana" do
    assert OpeningHours.status(%{}, nil, at_local(12, 0)) == {:closed, nil}
  end

  test "pausado hoje sobrepõe o horário" do
    paused_until = DateTime.add(at_local(12, 0), 3600)
    assert OpeningHours.status(@hours, paused_until, at_local(12, 0)) == {:paused}
  end

  test "pausa vencida não vale mais" do
    paused_until = DateTime.add(at_local(12, 0), -60)
    assert OpeningHours.status(@hours, paused_until, at_local(12, 0)) == {:open, "22h"}
  end

  test "minutos quebrados aparecem no rótulo" do
    hours = %{"mon" => [[660, 1350]]}
    assert OpeningHours.status(hours, nil, at_local(12, 0)) == {:open, "22h30"}
  end
end
