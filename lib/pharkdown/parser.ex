defmodule Pharkdown.Parser do

  # alias Pharkdown.Formater

  @known_environments [
    "document", "doc", "blockcode", "bcode"
  ]
  @environment_substitution %{
    "doc"   => "document",
    "bcode" => "blockcode"
  }

  def parse(string, options) do
    string
    |> String.replace("\r", "")
    |> tokenize(options)
  end

  @doc """
  Méthode qui prend un texte en entrée (qui peut être long) et le
  découpe en blocs identifié par des atoms.

  ## Examples

    iex> Pharkdown.Parser.tokenize("Une simple phrase")
    {:paragraph, [content: "Une simple phrase"]}

    iex> Pharkdown.Parser.tokenize("# Un titre simple")
    {:title, [content: "Un titre simple", level: 1]}
    
  """
  # Voilà comment on s'y prend :
  # 1) on cherche tous les textes reconnaissables (environnement, bloc de
  #    code, titre)
  # 2) on les remplace dans le texte par des 'KNOWN<X>BLOCK' en les 
  #    conservant dans une table.
  # 3) une fois que tout le texte a été analysé, on le parse séquentiellement
  #    pour obtenir une liste de tokens
  @regex_titres ~r/^(\#{1,7}) (.+)$/m
  @regex_blockcode ~r/(~~~|```)([a-z]+\n)?(.+)\n\1/ms
  @regex_known_environments ~r/(#{Enum.join(@known_environments, "|")})\/(.+|\n)\/\\1/m
  def tokenize(string, options \\ []) do
    collector = %{texte: string, tokens: [], index: 0, options: options}
    
    
    collector = collector
    |> scan_titres_in()
    |> scan_blockcode_in()
    |> scan_for_known_environments()

    IO.inspect(collector, label: "\nCOLLECTOR")

    ["bouton"]
  end

  defp scan_titres_in(collector) do
    case Regex.scan(@regex_titres, collector.texte) do
    nil -> collector
    res -> Enum.reduce(res, collector, fn groupes, collector ->
        [tout, level, contenu] = groupes

        # Données pour le token
        data = [
          index: collector.index + 1,
          contenu: contenu, 
          level: String.length(level)
        ]
        add_to_collector(collector, :title, data, tout)
      end)
    end
  end

  defp scan_blockcode_in(collector) do
    case Regex.scan(@regex_blockcode, collector.texte) do
      nil -> collector
      res -> Enum.reduce(res, collector, fn groupes, collector ->
          [tout, _amorce, langage, contenu] = groupes
  
          # Données pour le token
          data = [
            index: collector.index + 1,
            contenu: contenu, 
            langage: String.trim(langage)
          ]
          add_to_collector(collector, :blockcode, data, tout)
        end)
      end
  end

  defp add_to_collector(collector, type, data, tout) do
    remp  = "KWNON#{data[:index]}BLOC"
    new_texte = String.replace(collector.texte, tout, remp)
    Map.merge(collector, %{
      index:  data[:index], 
      texte:  new_texte,
      tokens: collector.tokens ++ [{type, data}]
    })
  end
  # La dernière fonction qui va vraiment renvoyer les tokens,
  # c'est à dire une liste sous la forme :
  # [
  #   {:type, [data]}
  #   {:type, [data]}
  #   {:type, [data]}
  #   etc.
  # ]
  defp scan_for_known_environments(collector) do
    collector.tokens

    collector =
      Regex.scan(@regex_known_environments, collector.texte)
      |> Enum.reduce(collector, &treat_known_environment/2)

    collector # pour le moment
  end

  defp treat_known_environment(found, collector) do
    collector # pour le moment
  end

end #/module Pharkdown.Parser