defmodule Sisyphe.Render do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:arxiv_id, :status, :html]}
  schema "renders" do
    field :arxiv_id, :string
    field :status, :string

    timestamps()
  end

  @doc false
  def changeset(render, attrs) do
    render
    |> cast(attrs, [:arxiv_id, :status])
    |> validate_required([:arxiv_id, :status])
    |> unique_constraint(:arxiv_id)
  end
end
