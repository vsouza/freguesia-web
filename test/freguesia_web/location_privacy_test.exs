defmodule FreguesiaWeb.LocationPrivacyTest do
  # Reads only the filter configuration, so it does not need the database or the endpoint.
  use ExUnit.Case, async: true

  test "request logs hide the browser point and the Firebase ID token" do
    params = %{
      "geo" => %{"neighborhood" => "savassi", "lat" => "-19.938", "lng" => "-43.939"},
      "id_token" => "eyJhbGciOi.secret",
      "neighborhood" => "savassi"
    }

    filtered = Phoenix.Logger.filter_values(params)

    assert filtered["geo"]["lat"] == "[FILTERED]"
    assert filtered["geo"]["lng"] == "[FILTERED]"
    assert filtered["id_token"] == "[FILTERED]"
    assert filtered["geo"]["neighborhood"] == "savassi"
    assert filtered["neighborhood"] == "savassi"
  end
end
