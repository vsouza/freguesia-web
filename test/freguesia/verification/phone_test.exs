defmodule Freguesia.Verification.PhoneTest do
  use ExUnit.Case, async: true

  alias Freguesia.Verification.Phone

  test "accepts formatting, with or without +55" do
    assert Phone.normalize("(31) 99999-9999") == {:ok, "+5531999999999"}
    assert Phone.normalize("+55 31 99999-9999") == {:ok, "+5531999999999"}
    assert Phone.normalize("5531999999999") == {:ok, "+5531999999999"}
  end

  test "accepts 10-digit landlines" do
    assert Phone.normalize("(31) 3333-4444") == {:ok, "+553133334444"}
  end

  test "area code 55 without country code is not confused with Brazil's country code" do
    assert Phone.normalize("55 99999-9999") == {:ok, "+5555999999999"}
  end

  test "rejects a short number, letters and empty input" do
    assert Phone.normalize("123") == :error
    assert Phone.normalize("abc") == :error
    assert Phone.normalize("") == :error
    assert Phone.normalize(nil) == :error
  end
end
