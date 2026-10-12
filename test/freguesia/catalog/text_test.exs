defmodule Freguesia.Catalog.TextTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Freguesia.Catalog.Text

  doctest Freguesia.Catalog.Text

  property "normalize é idempotente" do
    check all(name <- string(:printable, min_length: 0, max_length: 80)) do
      once = Text.normalize(name)
      assert Text.normalize(once) == once
    end
  end

  property "normalize não deixa acento, maiúscula nem & no resultado" do
    check all(name <- string(:printable, max_length: 80)) do
      result = Text.normalize(name)
      refute String.contains?(result, "&")
      assert result == String.downcase(result)
      refute Regex.match?(~r/\p{Mn}/u, result)
    end
  end

  property "slugify só usa a-z, 0-9 e hífen" do
    check all(name <- string(:printable, max_length: 80)) do
      assert Regex.match?(~r/^[a-z0-9]*(-[a-z0-9]+)*$/, Text.slugify(name))
    end
  end

  test "casa acentos e & na busca" do
    assert Text.normalize("Pão de Açúcar & Cia") == "pao de acucar e cia"
  end
end
