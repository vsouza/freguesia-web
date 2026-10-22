defmodule FreguesiaWeb.Admin.BackofficeLiveTest do
  use FreguesiaWeb.ConnCase, async: true

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Fixtures, Repo}
  alias Freguesia.Reports.{Complaint, Report}

  # Logs an operator in through the real sign-in and 2FA routes.
  defp logged_in(conn) do
    operator = Fixtures.operator()
    {:ok, operator, _uri} = Admin.start_totp_enrollment(operator)

    {:ok, operator} =
      Admin.confirm_totp_enrollment(operator, NimbleTOTP.verification_code(operator.totp_secret))

    conn =
      post(conn, ~p"/admin/sign-in", %{
        "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
      })

    conn =
      post(conn, ~p"/admin/sign-in/code", %{
        "totp" => %{"code" => NimbleTOTP.verification_code(operator.totp_secret)}
      })

    assert redirected_to(conn) == ~p"/admin/verifications"
    {conn, operator}
  end

  defp complaint!(place, reason \\ :wrong_or_scam) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert!(%Complaint{
      place_id: place.id,
      source: :form,
      reason: reason,
      status: :open,
      inserted_at: now,
      updated_at: now
    })
  end

  test "the places list filters by name and status", %{conn: conn} do
    {conn, _op} = logged_in(conn)
    Fixtures.verified_place(%{name: "Cantina Procurada"})
    Fixtures.verified_place(%{name: "Outra Casa"})

    {:ok, view, _html} = live(conn, ~p"/admin/places?q=cantina")
    assert has_element?(view, "#places", "Cantina Procurada")
    refute has_element?(view, "#places", "Outra Casa")
  end

  test "pausing a place for today records it in the history", %{conn: conn} do
    {conn, _op} = logged_in(conn)
    place = Fixtures.verified_place(%{name: "Padaria Pausada"})

    {:ok, view, _html} = live(conn, ~p"/admin/places/#{place.id}")
    view |> element("#pause") |> render_click()

    assert has_element?(view, "#resume")
    assert has_element?(view, "#audit", "place.pause")
  end

  test "removing a place needs a reason and then leaves the list", %{conn: conn} do
    {conn, _op} = logged_in(conn)
    place = Fixtures.verified_place(%{name: "Lanchonete Antiga"})

    {:ok, view, _html} = live(conn, ~p"/admin/places/#{place.id}")
    html = view |> form("#remove-form", remove: %{reason: "  "}) |> render_submit()
    assert html =~ "Write the reason" or html =~ "Escreva o motivo"

    assert {:error, {:live_redirect, %{to: "/admin/places"}}} =
             view
             |> form("#remove-form", remove: %{reason: "Pediu para sair no WhatsApp"})
             |> render_submit()

    assert Repo.get!(Freguesia.Catalog.Place, place.id).status == :removed
  end

  test "a held report can be released from the place page", %{conn: conn} do
    {conn, _op} = logged_in(conn)
    place = Fixtures.verified_place()
    open = Fixtures.open_for!(place)

    held =
      Repo.insert!(%Report{
        open_id: open.id,
        place_id: place.id,
        device_id: Ecto.UUID.generate(),
        outcome: :worked,
        savings_band: "le10",
        valid: false,
        invalid_reason: "batch_review",
        weight: Decimal.new("1.0"),
        answered_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, view, _html} = live(conn, ~p"/admin/places/#{place.id}")
    assert has_element?(view, "#held-#{held.id}")

    view |> element("#held-#{held.id} button") |> render_click()
    refute has_element?(view, "#held-#{held.id}")
  end

  test "closing a complaint returns the WhatsApp button on the public page", %{conn: conn} do
    {conn_admin, _op} = logged_in(conn)
    place = Fixtures.verified_place(%{name: "Pizzaria Denunciada"})
    complaint = complaint!(place)
    complaint!(place)

    {:ok, public, _} = live(build_conn(), ~p"/places/#{place.slug}")
    assert has_element?(public, "#whatsapp-cta", "Número em revisão")

    {:ok, view, _html} = live(conn_admin, ~p"/admin/complaints")
    assert has_element?(view, "#complaint-#{complaint.id}")

    view
    |> form("#close-#{complaint.id}",
      complaint: %{id: complaint.id, resolution: "Número confirmado"}
    )
    |> render_submit()

    assert Repo.get!(Complaint, complaint.id).status == :closed

    # One complaint is still open, below the threshold of two: the button is back.
    {:ok, public_after, _} = live(build_conn(), ~p"/places/#{place.slug}")
    refute has_element?(public_after, "#whatsapp-cta", "Número em revisão")
    assert has_element?(public_after, "a#whatsapp-cta")
  end

  test "the backoffice needs a login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/sign-in"}}} = live(conn, ~p"/admin/places")
  end
end
