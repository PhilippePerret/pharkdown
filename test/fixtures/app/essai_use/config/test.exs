import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :essai_use, EssaiUseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DBx2JuKu3ahEkF2w0nTE6vV9wrdQ5CkU59Qd35I8mt3okhIU0fSZbRyhnTNNd1pk",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
