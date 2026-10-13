defmodule Freguesia.Verification.Checks do
  @moduledoc """
  The four automatic checks on the queue (PRD §7).

    * `code`: the WhatsApp code was confirmed
    * `profile_name`: the WhatsApp Business profile name matches the one provided
      (similarity ≥ 0.8). `pending` until the profile is read.
    * `in_pilot`: the business neighborhood is in the pilot
    * `no_complaints`: there are no open complaints

  Values: `"ok"`, `"fail"` or `"pending"`.
  """

  alias Freguesia.Catalog.{Place, Text}

  @similarity_threshold 0.8

  @doc "Evaluates the place. `open_complaints?` comes from the context, to keep this function pure."
  @spec evaluate(Place.t(), boolean()) :: %{String.t() => String.t()}
  def evaluate(%Place{} = place, open_complaints?) do
    %{
      "code" => "ok",
      "profile_name" => profile_name(place),
      "in_pilot" => if(place.neighborhood.pilot, do: "ok", else: "fail"),
      "no_complaints" => if(open_complaints?, do: "fail", else: "ok")
    }
  end

  @doc "All checks passed."
  def all_ok?(checks) when is_map(checks) do
    checks != %{} and Enum.all?(Map.values(checks), &(&1 == "ok"))
  end

  @doc "Name similarity in [0, 1], used in the profile check."
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
