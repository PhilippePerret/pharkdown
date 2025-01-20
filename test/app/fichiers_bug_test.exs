defmodule ParFichiersTests do
  @moduledoc """
  Module pour faire des tests avec des fichiers.

  Ce module a été pensé pour pouvoir tester facilement des pages de
  sites qui poseraient problème. Dès qu'une page pose problème, on
  crée un test ci-dessous et on appelle simplement dedans la méthode
  test_file/1 avec le chemin relatif dans Fixtures ou même le
  chemin absolu (mais c'est moins intéressant)

    test "mon test du fichier" do
      test_file(path/dans/fixture.phad)
    end

  """
  use ExUnit.Case

  alias Pharkdown.Engine


  # test "Test de l'accueil du site Phoenix Exploration" do
  #   test_file("textes/accueil.phad")
  # end

  # test "Test" do
  #   test_file("textes/bug-20250120-6:04.phad")
  # end

  test "Évaluation de fonction dans bloc code ne devrait pas se faire" do
    test_file("textes/Manuel.md")
  end

  defp test_file(relpath) do
    full_path = Path.expand(Path.join(["test","fixtures", relpath]))
    File.exists?(full_path) || raise "Le fichier #{inspect full_path} est introuvable."
    # --- test ---
    resultat = Engine.compile(full_path, Path.basename(full_path))
    IO.puts resultat
  end
end

# defmodule Pharkdown.Helpers do
#   def path(chemin), do: "<code>#{chemin}</code>" 
# end 
