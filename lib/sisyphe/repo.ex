defmodule Sisyphe.Repo do
  use Ecto.Repo,
    otp_app: :sisyphe,
    adapter: Ecto.Adapters.SQLite3
end
