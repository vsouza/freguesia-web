defmodule FreguesiaWeb.BusinessSignInTest do
  use FreguesiaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "without a Firebase web config, provider buttons are disabled and the note shows", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/business/sign-in")

    assert has_element?(view, "#sign-in-google[disabled]")
    assert has_element?(view, "#sign-in-apple[disabled]")
    assert has_element?(view, "#email-sign-in[disabled]")
    assert has_element?(view, "#sign-in-unavailable")
  end

  test "dev and test offer the e-mail sign-in form that uses the Fake identity", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/business/sign-in")

    assert has_element?(view, "#dev-sign-in-form[action='/business/session']")
  end
end

defmodule FreguesiaWeb.BusinessSignInConfiguredTest do
  use FreguesiaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Freguesia.Business

  @web %{
    apiKey: "test-key",
    authDomain: "freguesia-test.firebaseapp.com",
    projectId: "freguesia-test",
    appId: "1:000:web:000"
  }

  setup do
    previous = Application.get_env(:freguesia, :firebase_web)
    Application.put_env(:freguesia, :firebase_web, @web)
    on_exit(fn -> Application.put_env(:freguesia, :firebase_web, previous) end)
    :ok
  end

  test "with the web config, the browser gets it and the buttons are enabled", %{conn: conn} do
    assert Business.firebase_web_config() == @web

    {:ok, view, _html} = live(conn, ~p"/business/sign-in")

    assert has_element?(view, "#firebase-sign-in[phx-hook='FirebaseSignIn']")
    assert has_element?(view, "#firebase-sign-in[data-config*='freguesia-test']")
    refute has_element?(view, "#sign-in-google[disabled]")
    refute has_element?(view, "#sign-in-apple[disabled]")
    refute has_element?(view, "#sign-in-unavailable")
  end

  test "no config at all: the buttons stay disabled", %{conn: conn} do
    Application.put_env(:freguesia, :firebase_web, nil)

    {:ok, view, _html} = live(conn, ~p"/business/sign-in")
    assert has_element?(view, "#sign-in-google[disabled]")
  end
end
