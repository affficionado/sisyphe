defmodule SisypheWeb.PaperController do
  use SisypheWeb, :controller
  require Logger

  alias Sisyphe.Storage

  def show(conn, %{"id" => id}) do 
    if Storage.source_exists?(id) do
      Logger.info("sw: paper #{id} exists")
      case Storage.get(id) do
        nil -> 
          Storage.run_render_task(id)
          send_resp(conn, 202, "Accepted")
        %{status: "rendering"} -> send_resp(conn, 202, "Accepted")
        %{status: "success"} -> json(conn, Storage.get_with_html(id))
        %{status: _} = paper -> json(conn, paper)
      end
    else
      send_resp(conn, 404, "Not found")
    end
  end


  def update(_conn, %{"id" => id}) do
    IO.puts("updating #{id}")
  end
end
