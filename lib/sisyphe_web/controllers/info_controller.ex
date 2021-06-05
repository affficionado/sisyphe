defmodule SisypheWeb.InfoController do
  use SisypheWeb, :controller

  def show(conn, %{"id" => id}) do
    render(conn, "info.html", id: id)
  end
end
