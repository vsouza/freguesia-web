defmodule Freguesia.EventsTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.{Events, Repo}
  alias Freguesia.Events.Event

  test "records an event with a known name" do
    assert {:ok, event} = Events.track("whatsapp_open", %{place_slug: "x"}, nil)
    assert event.name == "whatsapp_open"
    assert Repo.get!(Event, event.id).props == %{"place_slug" => "x"}
  end

  test "rejects an event name outside the PRD's fixed list" do
    assert {:error, :unknown_event} = Events.track("clique_qualquer")
  end
end
