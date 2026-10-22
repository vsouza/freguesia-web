defmodule Freguesia.RateLimitTest do
  # async: false on purpose. The rate limit is off in test and this module turns it on
  # globally; in an async module it would leak into other tests sharing 127.0.0.1.
  use Freguesia.DataCase, async: false

  import Ecto.Query, only: [from: 2]

  alias Freguesia.Catalog.Place
  alias Freguesia.{Fixtures, RateLimit, Repo, Verification}
  alias Freguesia.Verification.Code

  setup do
    previous = Application.get_env(:freguesia, RateLimit)
    Application.put_env(:freguesia, RateLimit, enabled: true)
    :ets.delete_all_objects(RateLimit)
    on_exit(fn -> Application.put_env(:freguesia, RateLimit, previous) end)
    :ok
  end

  defp keys, do: [device: Ecto.UUID.generate(), ip24: Ecto.UUID.generate()]

  describe "check/2" do
    test "allows up to the limit, then denies" do
      keys = keys()

      for _ <- 1..3, do: assert(:ok = RateLimit.check(:verification_code, keys))
      assert {:error, :rate_limited} = RateLimit.check(:verification_code, keys)
    end

    test "denies when any one key is over the limit" do
      ip24 = Ecto.UUID.generate()

      for _ <- 1..3 do
        assert :ok = RateLimit.check(:verification_code, device: Ecto.UUID.generate(), ip24: ip24)
      end

      # A fresh device on the same IP is still denied.
      assert {:error, :rate_limited} =
               RateLimit.check(:verification_code, device: Ecto.UUID.generate(), ip24: ip24)
    end

    test "actions count separately" do
      keys = keys()

      for _ <- 1..3, do: RateLimit.check(:verification_code, keys)
      assert :ok = RateLimit.check(:admin_password, keys)
    end

    test "ignores keys without a value" do
      for _ <- 1..10,
          do: assert(:ok = RateLimit.check(:verification_code, device: nil, ip24: nil))
    end

    test "always allows when turned off" do
      Application.put_env(:freguesia, RateLimit, enabled: false)
      keys = keys()

      for _ <- 1..10, do: assert(:ok = RateLimit.check(:verification_code, keys))
    end
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
