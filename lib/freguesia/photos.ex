defmodule Freguesia.Photos do
  @moduledoc """
  Place photos on local disk (PRD §10 and §11).

  The file type is checked by its first bytes, not by the file name. Only JPEG,
  PNG and WebP are accepted. The original is stored as uploaded: resizing into the
  800×450 and 240×240 variants waits for an image library (libvips) in the runtime.

  The database keeps only the key (`photo_key`), for example
  `3f2c…-…-…a1.jpg`. The public URL is `/photos/:key`.
  """

  @max_bytes 5_000_000

  @doc "Upload size limit, in bytes."
  def max_bytes, do: @max_bytes

  @doc "Directory where photos are stored."
  def dir, do: Application.fetch_env!(:freguesia, :photo_dir)

  @doc "Detects the file extension from the first bytes. `nil` for unsupported files."
  def detect_extension(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "jpg"
  def detect_extension(<<0x89, "PNG\r\n", 0x1A, 0x0A, _::binary>>), do: "png"
  def detect_extension(<<"RIFF", _size::binary-size(4), "WEBP", _::binary>>), do: "webp"
  def detect_extension(_), do: nil

  @doc """
  Stores the bytes under a new random key. Returns `{:ok, key}` or `{:error, reason}`.
  """
  def store(binary) when is_binary(binary) do
    cond do
      byte_size(binary) > @max_bytes ->
        {:error, :too_large}

      ext = detect_extension(binary) ->
        key = "#{Ecto.UUID.generate()}.#{ext}"
        File.mkdir_p!(dir())
        File.write!(path(key), binary)
        {:ok, key}

      true ->
        {:error, :unsupported_type}
    end
  end

  @doc "Full path of a stored photo. Rejects keys that are not in the expected format."
  def path(key) do
    if valid_key?(key), do: Path.join(dir(), key), else: nil
  end

  @doc "Reads a stored photo by key. `:error` for unknown or malformed keys."
  def read(key) do
    with file when is_binary(file) <- path(key),
         {:ok, bytes} <- File.read(file) do
      {:ok, bytes}
    else
      _ -> :error
    end
  end

  @doc "Content type for a key."
  def content_type(key) when is_binary(key) do
    case Path.extname(key) do
      ".jpg" -> "image/jpeg"
      ".png" -> "image/png"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end

  def valid_key?(key) when is_binary(key) do
    Regex.match?(
      ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)\z/,
      key
    )
  end

  def valid_key?(_), do: false
end
