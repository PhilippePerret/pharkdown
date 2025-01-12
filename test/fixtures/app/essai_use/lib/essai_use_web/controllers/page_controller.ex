defmodule EssaiUseWeb.PageController do
  use EssaiUseWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
