defmodule FreguesiaWeb.RateLimitTest do
  # async: false on purpose. The rate limit is off in test and this module turns it on
  # globally; in an async module it would leak into other tests sharing 127.0.0.1.
  use FreguesiaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Fixtures, RateLimit}

  setup do
    previous = Application.get_env(:freguesia, RateLimit)
    Application.put_env(:freguesia, RateLimit, enabled: true)
    :ets.delete_all_objects(RateLimit)
    on_exit(fn -> Application.put_env(:freguesia, RateLimit, previous) end)
    :ok
  end

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

  describe "backoffice login" do
    test "after 5 password attempts, even the right password gets 429", %{conn: conn} do
      operator = Fixtures.operator()

      for _ <- 1..5 do
        conn =
          post(conn, ~p"/admin/sign-in", %{
            "operator" => %{"email" => operator.email, "password" => "errada-errada-errada"}
          })

        assert html_response(conn, 200)
      end

      conn =
        post(conn, ~p"/admin/sign-in", %{
          "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
        })

      assert html_response(conn, 429)
      assert get_session(conn, :pending_operator_id) == nil
    end

    test "the email limit ignores case and spaces", %{conn: conn} do
      operator = Fixtures.operator()

      for variant <- [operator.email, String.upcase(operator.email), " #{operator.email} "] do
        for _ <- 1..2 do
          post(conn, ~p"/admin/sign-in", %{
            "operator" => %{"email" => variant, "password" => "errada-errada-errada"}
          })
        end
      end

      # 6 attempts so far; a new IP does not help, the email is over the limit.
      assert {:error, :rate_limited} =
               RateLimit.check(:admin_password,
                 email: operator.email,
                 ip24: Ecto.UUID.generate()
               )
    end

    test "after 5 wrong app codes, even the right code gets 429", %{conn: conn} do
      operator = Fixtures.operator()
      {:ok, operator, _uri} = Admin.start_totp_enrollment(operator)

      {:ok, operator} =
        Admin.confirm_totp_enrollment(
          operator,
          NimbleTOTP.verification_code(operator.totp_secret)
        )

      conn =
        post(conn, ~p"/admin/sign-in", %{
          "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
        })

      assert redirected_to(conn) == ~p"/admin/sign-in/code"
      right_code = NimbleTOTP.verification_code(operator.totp_secret)
      wrong_code = if right_code == "000000", do: "111111", else: "000000"

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
  end
end
