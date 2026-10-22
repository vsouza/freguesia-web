defmodule Freguesia.RateLimitTest do
  # async: false on purpose: see Freguesia.RateLimitHelpers.
  use Freguesia.DataCase, async: false

  import Ecto.Query, only: [from: 2]
  import Freguesia.RateLimitHelpers

  alias Freguesia.Catalog.Place
  alias Freguesia.{Fixtures, RateLimit, Repo, Verification}
  alias Freguesia.Verification.Code

  setup :enable_rate_limit

  defp keys, do: [device: Ecto.UUID.generate(), ip: Ecto.UUID.generate()]

  describe "check/2" do
    test "allows up to the limit, then denies" do
      keys = keys()

      for _ <- 1..3, do: assert(:ok = RateLimit.check(:verification_code, keys))
      assert {:error, :rate_limited} = RateLimit.check(:verification_code, keys)
    end

    test "denies when any one key is over the limit" do
      ip = Ecto.UUID.generate()

      for _ <- 1..3 do
        assert :ok = RateLimit.check(:verification_code, device: Ecto.UUID.generate(), ip: ip)
      end

      # A fresh device on the same IP is still denied.
      assert {:error, :rate_limited} =
               RateLimit.check(:verification_code, device: Ecto.UUID.generate(), ip: ip)
    end

    test "a denied request counts on no key" do
      device = Ecto.UUID.generate()
      busy_ip = Ecto.UUID.generate()

      for _ <- 1..3, do: RateLimit.check(:verification_code, ip: busy_ip)

      for _ <- 1..5 do
        assert {:error, :rate_limited} =
                 RateLimit.check(:verification_code, device: device, ip: busy_ip)
      end

      # The refusals did not use up the device's quota: from another IP it has all 3.
      for _ <- 1..3 do
        assert :ok =
                 RateLimit.check(:verification_code, device: device, ip: Ecto.UUID.generate())
      end
    end

    test "actions count separately" do
      keys = keys()

      for _ <- 1..3, do: RateLimit.check(:verification_code, keys)
      assert :ok = RateLimit.check(:admin_password, keys)
    end

    test "ignores keys without a value" do
      for _ <- 1..10, do: assert(:ok = RateLimit.check(:verification_code, device: nil, ip: nil))
    end

    test "always allows when turned off" do
      Application.put_env(:freguesia, RateLimit, enabled: false)
      keys = keys()

      for _ <- 1..10, do: assert(:ok = RateLimit.check(:verification_code, keys))
    end
  end

  describe "ip_key/1" do
    test "IPv4: one key per address" do
      assert RateLimit.ip_key("200.10.20.30") == RateLimit.ip_key("200.10.20.30")
      refute RateLimit.ip_key("200.10.20.30") == RateLimit.ip_key("200.10.20.31")
    end

    test "IPv6: one key per /64" do
      key = RateLimit.ip_key("2804:14c:1:2:aaaa:bbbb:cccc:dddd")

      assert is_binary(key)
      assert key == RateLimit.ip_key("2804:14c:1:2::1")
      refute key == RateLimit.ip_key("2804:14c:1:3::1")
    end

    test "an IPv4 address mapped into IPv6 is the same client" do
      assert RateLimit.ip_key("::ffff:200.10.20.30") == RateLimit.ip_key("200.10.20.30")
    end

    test "is not the IP in the clear" do
      refute RateLimit.ip_key("200.10.20.30") =~ "200.10"
    end

    test "nil for anything that is not an IP" do
      assert RateLimit.ip_key("not-an-ip") == nil
      assert RateLimit.ip_key(nil) == nil
    end
  end

  test "window_minutes/1 comes from the configured limit" do
    assert RateLimit.window_minutes(:verification_code) == 10
    assert RateLimit.window_minutes(:admin_password) == 15
  end

  describe "verification code" do
    test "the 4th signup from the same client is refused before anything is saved" do
      keys = keys()
      owner = Fixtures.business_account()

      for _ <- 1..3 do
        assert {:ok, _place, :sent} =
                 Verification.submit_signup(Fixtures.signup_params(), owner.id, keys)
      end

      places_before = Repo.aggregate(Place, :count)

      assert {:error, :rate_limited} =
               Verification.submit_signup(Fixtures.signup_params(), owner.id, keys)

      assert Repo.aggregate(Place, :count) == places_before
    end

    test "an invalid form does not use up the limit" do
      keys = keys()
      owner = Fixtures.business_account()

      for _ <- 1..5 do
        assert {:error, %Ecto.Changeset{}} =
                 Verification.submit_signup(
                   Fixtures.signup_params(%{"category_id" => nil}),
                   owner.id,
                   keys
                 )
      end

      assert {:ok, _place, :sent} =
               Verification.submit_signup(Fixtures.signup_params(), owner.id, keys)
    end

    test "resends count toward the same limit" do
      keys = keys()
      owner = Fixtures.business_account()

      {:ok, place, :sent} = Verification.submit_signup(Fixtures.signup_params(), owner.id, keys)

      skip_resend_wait(place)
      assert {:ok, %Code{}} = Verification.resend_code(place.id, keys)
      skip_resend_wait(place)
      assert {:ok, %Code{}} = Verification.resend_code(place.id, keys)
      skip_resend_wait(place)
      assert {:error, :rate_limited} = Verification.resend_code(place.id, keys)
    end

    test "a resend that is too soon does not use up the limit" do
      keys = keys()
      owner = Fixtures.business_account()

      {:ok, place, :sent} = Verification.submit_signup(Fixtures.signup_params(), owner.id, keys)

      for _ <- 1..5, do: assert({:error, :too_soon} = Verification.resend_code(place.id, keys))

      skip_resend_wait(place)
      assert {:ok, %Code{}} = Verification.resend_code(place.id, keys)
    end
  end

  # Moves the place's codes two minutes back, past the 60-second wait between sends.
  defp skip_resend_wait(place) do
    two_minutes_ago = DateTime.utc_now() |> DateTime.add(-120) |> DateTime.truncate(:second)

    Repo.update_all(from(c in Code, where: c.place_id == ^place.id),
      set: [inserted_at: two_minutes_ago]
    )
  end
end
