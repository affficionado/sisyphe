# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :sisyphe,
  ecto_repos: [Sisyphe.Repo]

config :sisyphe,
  storage_dir: "priv/storage",
  typesetting_dir: "priv/typesetting"

# Configures the endpoint
config :sisyphe, SisypheWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "185JAMrWQOHgcCIpTK5tv4ILfL72xO0sNI16/b9OVPhvAjPFceNoSrez8xQFh2HM",
  render_errors: [view: SisypheWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Sisyphe.PubSub,
  live_view: [signing_salt: "Mbcj7UCy"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
