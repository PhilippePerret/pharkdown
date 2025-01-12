defmodule Pharkdown.Formater do

  @doc """
  Fonction principale qui reçoit le découpage de la fonction Pharkdown.Parser.parse et
  le met en forme.
  """
  def formate(liste, options) when is_list(liste) do
    liste
    |> Enum.map(fn {type, data} -> formate(type, data, options) end)
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

  def formate(:list, data, _options) do
    tag = data[:type] == :regular && "ul" || "ol"
    accu =
      data[:content]
      |> Enum.reduce(%{content: "", current_level: 1}, fn dline, accu ->
        diff_level = dline[:level] - accu.current_level
        accu = change_level_in_list(accu, diff_level, tag)
        li = "<li>" <> dline[:content] <> "</li>"
        %{ accu | content: accu.content <> li }
      end)
    # Peut-être fermer le niveau courant
    accu = change_level_in_list(accu, 1 - accu.current_level, tag)
    |> IO.inspect(label: "Content de liste") 
    "<#{tag}>" <> accu.content <> "</#{tag}>"
  end

  defp change_level_in_list(accu, 0, tag), do: accu

  defp change_level_in_list(accu, diff, tag) when diff > 0 do
    Map.merge(accu, %{
      content: accu.content <> String.duplicate("<#{tag}>", diff),
      current_level: accu.current_level + diff
    })
  end
  defp change_level_in_list(accu, diff, tag) when diff < 0 do
    Map.merge(accu, %{
      content: accu.content <> String.duplicate("</#{tag}>", -diff),
      current_level: accu.current_level + diff
    })
  end

  def formate(type, _data, _options) do
    raise "Je ne sais pas encore traiter le type #{type}"
  end

end