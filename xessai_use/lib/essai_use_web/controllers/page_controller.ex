defmodule EssaiUseWeb.PageController do
  use EssaiUseWeb, :controller

  # C'est ça le cœur du test. Cet appel doit traiter ou actualiser
  # tous les fichirs .phad se trouvant dans le dossier 'page_html'.
  use Pharkdown

  alias Transformer, as: T

  def home(conn, _params) do
    render(conn, :home, %{
      texte_dynamique: "Ce texte est généré <dynamiquement> à l'aide de \<code><%= ... %>\</code>" |> T.h(:less_than)
    })
  end

  def essai(_conn, _params) do
    IO.puts "Je passe par l'essai"
  end
  
end
