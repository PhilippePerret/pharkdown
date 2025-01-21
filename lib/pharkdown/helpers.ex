defmodule Pharkdown.PharkdownHelpers do
  @moduledoc """
  Module définissant les fonctions d'helper utilisable dans toute 
  application chargeant l'extension.
  En plus de ces fonctions généralistes, le module importe les 
  fonctions que l'utilisateur/programmeur a définies dans 
  Pharkdown.Helpers
  """

  def red(string, _options \\ []) do
    ~s(<span style="color:red;">#{string}</span>)
  end

  @doc """
  Permet de coloriser un texte dans la couleur de son choix.

  ## Example

    iex> color("chaine", "FFF000")
    ~s(<span style="color:#FFF000;">chaine</span>)

    iex> color("en jaune ?", "#0FFFF0")
    ~s(<span style="color:#0FFFF0;">en jaune ?</span>)

  """
  def color(string, color, _options \\ []) do
    color = String.starts_with?(color, "#") && color || "##{color}"
    ~s(<span style="color:#{color};">#{string}</span>)
  end

  def path(string) do
    ~s(<code class="path">#{string}</code>)
  end
  def p(string), do: path(string)


  def __liste_fonctions() do
    "Je dois faire la liste des fonctions."
  end
end