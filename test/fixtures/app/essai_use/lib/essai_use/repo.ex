defmodule EssaiUse.Repo do
  use Ecto.Repo,
    otp_app: :essai_use,
    adapter: Ecto.Adapters.Postgres
end
