defmodule Freguesia.PhotosTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.{Backoffice, Fixtures, Photos}

  # 1x1 PNG
  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
       )

  test "detects JPEG, PNG and WebP by their first bytes" do
    assert Photos.detect_extension(<<0xFF, 0xD8, 0xFF, 0xE0, 0, 0>>) == "jpg"
    assert Photos.detect_extension(@png) == "png"
    assert Photos.detect_extension(<<"RIFF", 0, 0, 0, 0, "WEBP", 0>>) == "webp"
  end

  test "rejects anything else, whatever the file name says" do
    assert Photos.detect_extension("<html>not an image</html>") == nil
    assert {:error, :unsupported_type} = Photos.store("<html>not an image</html>")
  end

  test "stores the file under a random key and returns it" do
    assert {:ok, key} = Photos.store(@png)
    assert String.ends_with?(key, ".png")
    assert File.read!(Photos.path(key)) == @png
  end

  test "refuses files above the size limit" do
    big = @png <> String.duplicate("0", Photos.max_bytes())
    assert {:error, :too_large} = Photos.store(big)
  end

  test "keys outside the expected format never map to a path" do
    assert Photos.path("../../config/config.exs") == nil
    assert Photos.path("not-a-key.png") == nil
    assert Photos.content_type("abc.webp") == "image/webp"
  end

  test "replacing the photo of a place is audited" do
    operator = Fixtures.operator()
    place = Fixtures.verified_place()
    {:ok, key} = Photos.store(@png)

    assert {:ok, updated} = Backoffice.replace_photo(place, operator, key)
    assert updated.photo_key == key
    assert [entry] = Freguesia.Admin.audit_entries("place", place.id)
    assert entry.action == "place.photo"
  end
end
