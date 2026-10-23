defmodule FreguesiaWeb.RateLimitTest do
  # async: false on purpose: see Freguesia.RateLimitHelpers. The client IP header test
  # also swaps global config.
  use FreguesiaWeb.ConnCase, async: false

  import Freguesia.RateLimitHelpers
  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Fixtures, RateLimit}

  setup :enable_rate_limit

  @wrong_password "errada-errada-errada"

  describe "place signup" do
    test "the 4th code request from the same IP stays on the form with an error", %{conn: conn} do
      conn = Fixtures.sign_in_business(conn)

      for _ <- 1..3 do
        view = submit_signup(conn)
        assert has_element?(view, "#code-form")
      end

      view = submit_signup(conn)

      refute has_element?(view, "#code-form")
      assert has_element?(view, "#signup-form")
      assert has_element?(view, "#flash-error")
    end
  end

  describe "backoffice password" do
    test "after 5 attempts from one IP, even the right password gets 429", %{conn: conn} do
      operator = Fixtures.operator()

      for _ <- 1..5 do
        assert conn |> post_password(operator.email, @wrong_password) |> html_response(200)
      end

      conn = post_password(conn, operator.email, Fixtures.password())

      assert html_response(conn, 429)
      assert get_session(conn, :pending_operator_id) == nil
    end

    test "failures from another IP do not lock the operator out", %{conn: conn} do
      operator = Fixtures.operator()
      attacker = %{conn | remote_ip: {10, 0, 0, 1}}

      for _ <- 1..10, do: post_password(attacker, operator.email, @wrong_password)

      conn = post_password(conn, operator.email, Fixtures.password())
      assert redirected_to(conn) == ~p"/admin/sign-in/2fa-setup"
      assert get_session(conn, :pending_operator_id) == operator.id
    end
  end

  describe "backoffice app code" do
    test "after 5 wrong codes, even the right code gets 429", %{conn: conn} do
      operator = enrolled_operator()
      conn = post_password(conn, operator.email, Fixtures.password())
      assert redirected_to(conn) == ~p"/admin/sign-in/code"

      right_code = NimbleTOTP.verification_code(operator.totp_secret)
      wrong_code = wrong_code(right_code)

      conn =
        Enum.reduce(1..5, conn, fn _, conn ->
          conn =
            post(recycle(conn), ~p"/admin/sign-in/code", %{"totp" => %{"code" => wrong_code}})

          assert html_response(conn, 200)
          conn
        end)

      conn = post(recycle(conn), ~p"/admin/sign-in/code", %{"totp" => %{"code" => right_code}})

      assert html_response(conn, 429)
      assert get_session(conn, :operator_id) == nil
    end

    test "first setup: after 5 wrong codes, even the right code gets 429", %{conn: conn} do
      operator = Fixtures.operator()
      conn = post_password(conn, operator.email, Fixtures.password())
      assert redirected_to(conn) == ~p"/admin/sign-in/2fa-setup"

      {:ok, operator, _uri} = Admin.start_totp_enrollment(operator)
      right_code = NimbleTOTP.verification_code(operator.totp_secret)
      wrong_code = wrong_code(right_code)

      conn =
        Enum.reduce(1..5, conn, fn _, conn ->
          conn =
            post(recycle(conn), ~p"/admin/sign-in/2fa-setup", %{
              "totp" => %{"code" => wrong_code}
            })

          assert redirected_to(conn) == ~p"/admin/sign-in/2fa-setup"
          conn
        end)

      conn =
        post(recycle(conn), ~p"/admin/sign-in/2fa-setup", %{"totp" => %{"code" => right_code}})

      assert html_response(conn, 429)
      assert get_session(conn, :operator_id) == nil
    end
  end

  describe "client IP" do
    setup do
      previous = Application.get_env(:freguesia, :client_ip_header)
      on_exit(fn -> Application.put_env(:freguesia, :client_ip_header, previous) end)
    end

    test "the Fly header is ignored unless configured", %{conn: conn} do
      Application.delete_env(:freguesia, :client_ip_header)

      conn = conn |> put_req_header("fly-client-ip", "10.9.8.7") |> get(~p"/terms")

      assert get_session(conn, "rate_ip") == RateLimit.ip_key("127.0.0.1")
    end

    test "the configured header gives the client IP", %{conn: conn} do
      Application.put_env(:freguesia, :client_ip_header, "fly-client-ip")

      conn = conn |> put_req_header("fly-client-ip", "10.9.8.7") |> get(~p"/terms")

      assert get_session(conn, "rate_ip") == RateLimit.ip_key("10.9.8.7")
    end
  end

  # A fresh signup page, filled in and submitted. Picking the segment first shows the
  # food type field.
  defp submit_signup(conn) do
    {:ok, view, _html} = live(conn, ~p"/business/register")

    view
    |> element("#signup-form")
    |> render_change(%{"signup" => %{"segment_id" => Fixtures.restaurants().id}})

    view |> form("#signup-form", signup: Fixtures.signup_params()) |> render_submit()
    view
  end

  defp post_password(conn, email, password) do
    post(conn, ~p"/admin/sign-in", %{"operator" => %{"email" => email, "password" => password}})
  end

  # Operator with the authenticator app already set up.
  defp enrolled_operator do
    {:ok, operator, _uri} = Admin.start_totp_enrollment(Fixtures.operator())

    {:ok, operator} =
      Admin.confirm_totp_enrollment(operator, NimbleTOTP.verification_code(operator.totp_secret))

    operator
  end

  defp wrong_code("000000"), do: "111111"
  defp wrong_code(_right_code), do: "000000"
end
