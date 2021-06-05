defmodule Sisyphe.Storage do
  import Ecto.Query, only: [from: 2]
  alias Sisyphe.Repo
  alias Sisyphe.Render
  # alias Bureau.Arxiv
  require Logger

  def dir, do: Path.expand("../../priv/storage", __DIR__)
  def source_dir(id), do: Path.join([dir(), "source", "#{id}"])
  def html_dir(id), do: Path.join([dir(), "html", "#{id}"])
  def raw_path(id), do: Path.join(html_dir(id), "raw.html")
  def cooked_path(id), do: Path.join(html_dir(id), "cooked.html")

  def prepare_dir(id) do
    source = source_dir(id)
    html = html_dir(id)
    File.mkdir_p(source)
    File.mkdir_p(html)
    {source, html}
  end

  def source_exists?(id) do
    # Arxiv.paper_exists?(id)
    true
  end
  
  def rendered?(id) do
    Repo.exists?(from r in Render, where: r.arxiv_id == ^id)
  end
    
  def get(id) do
    Repo.get_by(Render, arxiv_id: id)
  end

  def get_with_html(id) do
    id
    |> get()
    |> Map.put(:html, get_html(id)) 
  end

  def get_html(id) do
    id
    |> cooked_path()
    |> File.read()
    |> case do
      {:ok, html} -> html
      {:error, _} -> nil
    end
  end

  def insert(id) do
    %Render{arxiv_id: id, status: "rendering"}
    |> Repo.insert()
  end

  def update(paper, attrs) do
    paper
    |> Render.changeset(attrs)
    |> Repo.update()
  end

  def run_render_task(id) do
    case insert(id) do
      {:ok, paper} -> 
        Task.Supervisor.start_child(
          Sisyphe.RenderSupervisor,
          Sisyphe.RenderTask,
          :run,
          [paper],
          shutdown: :timer.minutes(10)
        )
      {:error, _} -> :noop
    end
  end
end
