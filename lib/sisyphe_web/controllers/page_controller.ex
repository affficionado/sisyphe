defmodule SisypheWeb.PageController do
  use SisypheWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
