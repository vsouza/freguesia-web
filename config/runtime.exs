import Config

# Firebase web config for the business sign-in page (PRD §6). These values are public
# (they identify the project, they are not secrets). Missing values keep Google and
# Apple sign-in disabled, so every environment still works without a Firebase project.
firebase_web =
  [
    apiKey: System.get_env("FIREBASE_API_KEY"),
    authDomain: System.get_env("FIREBASE_AUTH_DOMAIN"),
    projectId: System.get_env("FIREBASE_PROJECT_ID"),
    appId: System.get_env("FIREBASE_APP_ID")
  ]

config :freguesia,
       :firebase_web,
       if(Enum.all?(firebase_web, fn {_key, value} -> is_binary(value) and value != "" end),
         do: Map.new(firebase_web)
       )

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/freguesia start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :freguesia, FreguesiaWeb.Endpoint, server: true
end

config :freguesia, FreguesiaWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  # Fly's proxy puts the client's IP in this header, read by FreguesiaWeb.DeviceSession.
  config :freguesia, :client_ip_header, "fly-client-ip"

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :freguesia, Freguesia.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  # Used in message links (e.g. the place page after approval).
  config :freguesia, :public_url, "https://#{host}"

  # Local photo storage. Point PHOTO_DIR to a mounted volume in production.
  config :freguesia, :photo_dir, System.get_env("PHOTO_DIR") || "/app/data/photos"

  # Business sign-in: Firebase ID tokens, verified with the Identity Toolkit API key.
  config :freguesia, :business_identity, Freguesia.Business.Identity.Firebase
  config :freguesia, :firebase_api_key, System.get_env("FIREBASE_API_KEY")

  # Phase 0 (G1): staging uses the fake adapter. The real WhatsApp API
  # (Freguesia.Messaging.Cloud) belongs to phase 1 and must be wired here before production.

  config :freguesia, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :freguesia, FreguesiaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :freguesia, FreguesiaWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :freguesia, FreguesiaWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :freguesia, Freguesia.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
