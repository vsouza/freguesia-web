# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :freguesia,
  ecto_repos: [Freguesia.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  # Adaptador do WhatsApp Cloud API. Em dev e teste é o Fake (ver Freguesia.Messaging).
  messaging: Freguesia.Messaging.Fake

# Endereço público, usado nos links das mensagens (ex.: página do lugar)
config :freguesia, :public_url, "http://localhost:4000"

# Horário de funcionamento é calculado em America/Sao_Paulo (PRD §6 e §8)
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Jobs em fila no próprio Postgres (PRD §10)
config :freguesia, Oban,
  engine: Oban.Engines.Basic,
  repo: Freguesia.Repo,
  queues: [messaging: 5],
  plugins: [{Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}]

# Configure the endpoint
config :freguesia, FreguesiaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FreguesiaWeb.ErrorHTML, json: FreguesiaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Freguesia.PubSub,
  live_view: [signing_salt: "xInGy2CP"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :freguesia, Freguesia.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  freguesia: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  freguesia: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
