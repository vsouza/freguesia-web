defmodule Freguesia.Verification.PhoneTest do
  use ExUnit.Case, async: true

  alias Freguesia.Verification.Phone

  test "aceita máscara, com ou sem +55" do
    assert Phone.normalize("(31) 99999-9999") == {:ok, "+5531999999999"}
    assert Phone.normalize("+55 31 99999-9999") == {:ok, "+5531999999999"}
    assert Phone.normalize("5531999999999") == {:ok, "+5531999999999"}
  end

  test "aceita fixo de 10 dígitos" do
    assert Phone.normalize("(31) 3333-4444") == {:ok, "+553133334444"}
  end

  test "DDD 55 sem país não é confundido com o código do Brasil" do
    assert Phone.normalize("55 99999-9999") == {:ok, "+5555999999999"}
  end

  test "rejeita número curto, letras e vazio" do
    assert Phone.normalize("123") == :error
    assert Phone.normalize("abc") == :error
    assert Phone.normalize("") == :error
    assert Phone.normalize(nil) == :error
  end
end
