defmodule Freguesia.EventsTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.{Events, Repo}
  alias Freguesia.Events.Event

  test "grava um evento de nome conhecido" do
    assert {:ok, event} = Events.track("whatsapp_open", %{place_slug: "x"}, nil)
    assert event.name == "whatsapp_open"
    assert Repo.get!(Event, event.id).props == %{"place_slug" => "x"}
  end

  test "recusa nome fora da lista fixa do PRD" do
    assert {:error, :unknown_event} = Events.track("clique_qualquer")
  end
end
