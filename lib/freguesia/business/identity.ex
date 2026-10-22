defmodule Freguesia.Business.Identity do
  @moduledoc """
  Verifies the sign-in of a business account (PRD §6). The browser gets a Firebase ID
  token; this behaviour turns it into the claims we keep. Production uses
  `Freguesia.Business.Identity.Firebase`; dev and test use the Fake.
  """

  @type claims :: %{
          uid: String.t(),
          email: String.t() | nil,
          name: String.t() | nil,
          picture: String.t() | nil,
          provider: :google | :apple | :password
        }

  @callback verify(id_token :: String.t()) :: {:ok, claims()} | {:error, term()}
end
