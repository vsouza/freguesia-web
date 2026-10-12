defmodule Freguesia.Events do
  @moduledoc """
  In-house analytics (`events` table, PRD §9 and §11). Fixed names: any other
  name is rejected, so the dashboard does not spread into variations.
  """
  alias Freguesia.Events.Event
  alias Freguesia.Repo

  @names ~w(
    onboarding_started location_granted location_manual login_google login_email_sent
    home_viewed category_selected search_performed place_viewed whatsapp_open
    return_prompt_shown report_submitted favorite_added signup_started signup_code_confirmed
    ad_impression ad_click
  )

  @doc "Records an event. Returns `{:error, :unknown_event}` for names outside the list."
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
