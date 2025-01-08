defmodule Pharkdown.Formater do

  @doc """
  Fonction principale qui reçoit le découpage de la fonction Pharkdown.Parser.parse et
  le met en forme.
  """
  def formate(liste, _options) when is_list(liste) do
    liste
    |> Enum.map(fn {type, data} -> formate(type, data) end)
    |> Enum.join("\n")
  end


  def formate(:paragraph, data, _options) do
    # TODO Ajouter les classes, etc.
    "<p>" <> data[:content] <> "</p>"
  end

  def formate(:title, data, _options) do
    "<h#{data[:level]}>#{data[:content]}</h#{data[:level]}>"
  end

  def formate(:blockcode, data, _options) do
    data[:lines]
    |> Enum.join("\n")
  end

  def formate(type, _data, _options) do
    raise "Je ne sais pas traiter le type #{type}"
  end

end