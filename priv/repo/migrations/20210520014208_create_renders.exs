defmodule Sisyphe.Repo.Migrations.CreateRenders do
  use Ecto.Migration

  def change do
    create table("renders") do
      add :arxiv_id, :string
      add :status, :string

      timestamps()
    end

    create unique_index(:renders, [:arxiv_id])
  end
end
