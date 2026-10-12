defmodule Freguesia.Verification.Checks do
  @moduledoc """
  As quatro checagens automáticas da fila (PRD §7).

    * `code`: o código do WhatsApp foi confirmado
    * `profile_name`: o nome do perfil WhatsApp Business bate com o informado
      (similaridade ≥ 0,8). `pending` enquanto o perfil não for lido.
    * `in_pilot`: o bairro do negócio está no piloto
    * `no_reports`: não há denúncia aberta

  Valores: `"ok"`, `"fail"` ou `"pending"`.
  """

  alias Freguesia.Catalog.{Place, Text}

  @similarity_threshold 0.8

  @doc "Avalia o lugar. `open_complaints?` vem do contexto, para manter esta função pura."
  @spec evaluate(Place.t(), boolean()) :: %{String.t() => String.t()}
  def evaluate(%Place{} = place, open_complaints?) do
    %{
      "code" => "ok",
      "profile_name" => profile_name(place),
      "in_pilot" => if(place.neighborhood.pilot, do: "ok", else: "fail"),
      "no_reports" => if(open_complaints?, do: "fail", else: "ok")
    }
  end

  @doc "Todas as checagens passaram."
  def all_ok?(checks) when is_map(checks) do
    checks != %{} and Enum.all?(Map.values(checks), &(&1 == "ok"))
  end

  @doc "Similaridade de nomes em [0, 1], usada na checagem do perfil."
  def similarity(a, b) do
    String.jaro_distance(Text.normalize(a), Text.normalize(b))
  end

  defp profile_name(%Place{wa_profile_name: nil}), do: "pending"

  defp profile_name(%Place{} = place) do
    if similarity(place.name, place.wa_profile_name) >= @similarity_threshold,
      do: "ok",
      else: "fail"
  end
end
