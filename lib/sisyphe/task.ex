defmodule Sisyphe.RenderTask do
  use Task
  require Logger
  alias Sisyphe.Storage
  alias Sisyphe.RenderTask.{LaTeXML, Postprocessing}

  def start_link(paper) do
    Task.start_link(__MODULE__, :run, [paper])
  end

  def run(paper) do
    id = paper.arxiv_id
    {source_dir, _} = Storage.prepare_dir(id)

    Logger.add_backend({LoggerFileBackend, id})
    Logger.configure_backend({LoggerFileBackend, id}, 
      path: Path.join(source_dir, "run.log"),
      level: :info,
      metadata_filter: [paper: id]
    )

    {body, headers} = fetch_source(id)
    if renderable?(headers) do
      Logger.info("Paper source is LaTeX")
      with :ok              <- tar_xz(body, source_dir),
           {:ok, tex_path}  <- find_input_file(source_dir),
           :ok              <- LaTeXML.latexmlc(id, tex_path, Storage.raw_path(id)),
           :ok              <- Postprocessing.run(id, Storage.raw_path(id), Storage.cooked_path(id)) do
        set_status(paper, "success")
      else
        {:error, reason} -> 
          Logger.error(reason, paper: id)
          set_status(paper, "failure")
      end
    else
        Logger.error("Paper source is not LaTeX", paper: id)
        set_status(paper, "notlatex")
    end
    
    send_to_bureau(id)

    Logger.remove_backend({LoggerFileBackend, id}) 
  end

  def set_status(paper, status) do
    Logger.info("Setting status to #{status}", paper: paper.arxiv_id)
    {:ok, _} = Storage.update(paper, %{status: status})
  end

  def fetch_source(id) do
    Logger.info("Fetching source from arxiv...", paper: id)
    {:ok, %{status_code: 200, body: body, headers: headers}} = HTTPoison.get("https://arxiv.org/e-print/#{id}")
    {body, headers}
  end

  def renderable?(headers) do
    %{"Content-Type" => type} = Map.new(headers)
    type in ["application/x-eprint-tar", "application/x-eprint"]
  end

  def tar_xz(binary, out_dir) do
    Logger.info("Unpacking tarball...", paper: Path.basename(out_dir))
    :erl_tar.extract({:binary, binary}, [{:cwd, out_dir}, :compressed])
  end

  def find_input_file(source_dir) do 
    Logger.info("Finding 'main' tex input file", paper: Path.basename(source_dir))
    source_dir
    |> Path.join("*.tex")
    |> Path.wildcard()
    |> case do
      [] -> {:error, "no tex inputs in #{source_dir}"}
      [single] -> {:ok, single}
      filenames -> pick_from_multiple(filenames)
    end
  end

  def pick_from_multiple(tex_files) do
    Logger.info("Choosing main file from #{inspect tex_files}", 
      paper: tex_files |> Enum.at(0) |> Path.dirname() |> Path.basename())
    tex_files
    |> Enum.find(fn f -> Path.basename(f) in ["ms.tex", "main.tex"] end)
    |> case do
      nil -> {:error, "ambiguous tex input: #{inspect(tex_files)}"}
      filename -> {:ok, filename}
    end
  end

  def send_to_bureau(id) do
    url = Application.get_env(:sisyphe, :bureau_webhook)
    opts = [{"Content-Type", "application/json"}]
    body = Storage.get_with_html(id) |> Jason.encode!()

    HTTPoison.post(url, body, opts)
  end
end

defmodule Sisyphe.RenderTask.LaTeXML do
  require Logger

  def latexml_dir, do: Path.expand("../../priv/typesetting/latexml", __DIR__)

  def latexmlc(id, tex_path, out_path, latexml_dir \\ latexml_dir()) do
    out_dir = Path.dirname(out_path)
    args = [
      "--format", "html5",
      "--nodefaultresources",
      "--mathtex",
      "--navigationtoc", "context",
      "--svg",
      "--verbose",
      "--timestamp", "0",
      "--path", Path.join(latexml_dir, "packages"),
      "--preload", Path.join(latexml_dir, "engrafo.ltxml"),
      "--xsltparameter", "SIMPLIFY_HTML:true",
      "--source", tex_path,
      "--destination", out_path
    ]
    opts = [
      cd: out_dir,
      into: out_dir |> Path.join("latexmlc.log") |> File.stream!(),
      stderr_to_stdout: true, 
      parallelism: true
    ]
    Logger.info("Running latexmlc...", paper: id)
    case System.cmd("latexmlc", args, opts) do
      {_, 0} -> 
        Logger.info("Render completed! See latexmlc.log for warnings", paper: id)
        :ok
      {_, exit_code} -> 
        {:error, "latexmlc exited with #{exit_code}. See latexmlc.log for errors"}
    end
  end
end

defmodule Sisyphe.RenderTask.Postprocessing do
  require Logger

  def script_path, do: Path.expand("../../priv/typesetting/postprocess/index.js", __DIR__)
  def css_path, do: SisypheWeb.Endpoint.url() <> "/css/typesetting.css"

  def run(id, input_path, output_path) do
    args = [
      "-r", "esm",
      script_path(),
      input_path,
      output_path,
      "--css", css_path(),
    ]
    opts = [
      cd: Path.dirname(script_path()),
      parallelism: true
    ]
    Logger.info("Running postprocessing...")
    case System.cmd("node", args, opts) do
      {_, 0} -> 
        Logger.info("Postprocessing completed!", paper: id)
        :ok
      {log, exit_code} -> 
        {:error, "Postprocess script exited with #{exit_code}:\n#{log}"}
    end
  end
end
