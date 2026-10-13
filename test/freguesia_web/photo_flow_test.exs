defmodule FreguesiaWeb.PhotoFlowTest do
  use FreguesiaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Fixtures, Photos, Repo}
  alias Freguesia.Catalog.Place

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
       )

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

    conn
  end

  test "a stored photo is served with its content type and a long cache", %{conn: conn} do
    {:ok, key} = Photos.store(@png)

    conn = get(conn, ~p"/photos/#{key}")
    assert response(conn, 200) == @png
    assert get_resp_header(conn, "content-type") |> hd() =~ "image/png"
    assert get_resp_header(conn, "cache-control") |> hd() =~ "immutable"
  end

  test "unknown or malformed keys return 404", %{conn: conn} do
    assert response(get(conn, "/photos/#{Ecto.UUID.generate()}.png"), 404)
    assert response(get(conn, "/photos/..%2F..%2Fmix.exs"), 404)
  end

  test "an operator uploads a photo from the place page and the public page shows it", %{
    conn: conn
  } do
    conn = logged_in(conn)
    place = Fixtures.verified_place(%{name: "Mercearia Foto"})

    {:ok, view, _html} = live(conn, ~p"/admin/places/#{place.id}")

    photo =
      file_input(view, "#photo-form", :photo, [
        %{name: "fachada.png", content: @png, type: "image/png"}
      ])

    render_upload(photo, "fachada.png")
    view |> form("#photo-form") |> render_submit()

    assert has_element?(view, "#photo img")
    key = Repo.get!(Place, place.id).photo_key
    assert key

    {:ok, public, _html} = live(build_conn(), ~p"/places/#{place.slug}")
    assert has_element?(public, "img[src='/photos/#{key}']")
  end

  test "a file that is not an image is refused with a message", %{conn: conn} do
    conn = logged_in(conn)
    place = Fixtures.verified_place()

    {:ok, view, _html} = live(conn, ~p"/admin/places/#{place.id}")

    photo =
      file_input(view, "#photo-form", :photo, [
        %{name: "falsa.png", content: "<html>x</html>", type: "image/png"}
      ])

    render_upload(photo, "falsa.png")
    html = view |> form("#photo-form") |> render_submit()

    assert html =~ "JPG, PNG or WebP" or html =~ "JPG, PNG ou WebP"
    assert Repo.get!(Place, place.id).photo_key == nil
  end
end
