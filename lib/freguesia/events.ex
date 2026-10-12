defmodule Freguesia.Events do
  @moduledoc """
  Analytics próprio (tabela `events`, PRD §9 e §11). Nomes fixos: qualquer outro
  nome é recusado, para o painel não se espalhar em variações.
  """
  alias Freguesia.Events.Event
  alias Freguesia.Repo

  @names ~w(
    onboarding_started location_granted location_manual login_google login_email_sent
    home_viewed category_selected search_performed place_viewed whatsapp_open
    return_prompt_shown report_submitted favorite_added signup_started signup_code_confirmed
    ad_impression ad_click
  )

  @doc "Grava um evento. Devolve `{:error, :unknown_event}` para nomes fora da lista."
  def track(name, props \\ %{}, device_id \\ nil) do
    if name in @names do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %Event{}
      |> Ecto.Changeset.change(%{
        name: name,
        props: props,
        device_id: device_id,
        inserted_at: now,
        updated_at: now
      })
      |> Repo.insert()
    else
      {:error, :unknown_event}
    end
  end

  def names, do: @names
end
