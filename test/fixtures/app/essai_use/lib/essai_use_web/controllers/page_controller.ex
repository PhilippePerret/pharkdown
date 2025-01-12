defmodule EssaiUseWeb.PageController do
  use EssaiUseWeb, :controller

  # C'est ça le cœur du test. Cet appel doit traiter ou actualiser
  # tous les fichirs .phad se trouvant dans le dossier 'page_html'.
  use Pharkdown

  def home(conn, _params) do
    render(conn, :home)
  end
end
