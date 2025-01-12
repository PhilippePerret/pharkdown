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

  @doc """
  Formatage de liste définie par :
    * item 1
    * item 2
    ** item 2.1
    etc.

  ## Examples

    iex> Pharkdown.Formater.formate(:list, [type: :regular, first: 1, content: [[content: "Item 1", level: 1]]], [])
    "<ul><li>Item 1</li></ul>"

    iex> Pharkdown.Formater.formate(:list, [type: :ordered, first: 1, content: [[content: "Item 1", level: 1]]], [])
    "<ol><li>Item 1</li></ol>"

  """
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
    # |> IO.inspect(label: "Content de liste") 
    "<#{tag}>" <> accu.content <> "</#{tag}>"
  end

  # Formatage quelconque, non défini
  def formate(type, _data, _options) do
    raise "Je ne sais pas encore traiter le type #{type}"
  end



  @doc """
  Fonction principale qui reçoit le texte produit par la fonction 
  précédente et le finalise.
  C'est ici par exemple que sont traités les *italic* et autres 
  **gras** ainsi que les [lien](vers/quelque/chose)

  # Italiques
  iex> Pharkdown.Formater.formate("*italic* et *autre chose*", [])
  "<em>italic</em> et <em>autre chose</em>"
  # avec parasite
  iex>  Pharkdown.Formater.formate("*ita\\\\*lic* et *autre chose*", [])
  "<em>ita*lic</em> et <em>autre chose</em>"


  # Gras
  iex> Pharkdown.Formater.formate("**gras** et **autre gras**", [])
  "<strong>gras</strong> et <strong>autre gras</strong>"
  
  # avec parasite
  iex> Pharkdown.Formater.formate("**gras** et **autre \\\\*\\\\*gras**", [])
  "<strong>gras</strong> et <strong>autre **gras</strong>"

  # Gras italique
  iex> Pharkdown.Formater.formate("***gras et italique***", [])
  "<strong><em>gras et italique</em></strong>"

  # Souligné
  iex>  Pharkdown.Formater.formate("__souligné__ et __très souligné__", [])
  "<u>souligné</u> et <u>très souligné</u>"
  
  # avec parasite
  iex>  Pharkdown.Formater.formate("__souligné\\\\___ et __très\\\\_\\\\_souligné__", [])
  "<u>souligné_</u> et <u>très__souligné</u>"

  iex> Pharkdown.Formater.formate("[Mon lien](/vers/un/path)", [])
  "<a href=\\"/vers/un/path\\">Mon lien</a>"
  
  # Avec parasite
  iex> Pharkdown.Formater.formate("[Mon\\\\]\\\\(lien](/vers/un/path)", [])
  "<a href=\\"/vers/un/path\\">Mon](lien</a>"
  
  # Double
  iex> Pharkdown.Formater.formate("[Mon lien](/vers/un/path) et [autre lien](path/to)", [])
  "<a href=\\"/vers/un/path\\">Mon lien</a> et <a href=\\"path/to\\">autre lien</a>"

  iex> Pharkdown.Formater.formate("[Mon autre lien](/vers/un/autre|class=exergue, style=font-size: 12pt)", [])
  "<a href=\\"/vers/un/autre\\" class=\\"exergue\\" style=\\"font-size: 12pt\\">Mon autre lien</a>"

  # Exposants
  iex> Pharkdown.Formater.formate("1^er 1^re 1^ere 2^e 3^eme 4^ème 1^res 1^eres note^1 autre note^123a", [])
  "1<sup>er</sup> 1<sup>re</sup> 1<sup>re</sup> 2<sup>e</sup> 3<sup>e</sup> 4<sup>e</sup> 1<sup>res</sup> 1<sup>res</sup> note<sup>1</sup> autre note<sup>123a</sup>"

  # parasite
  iex> Pharkdown.Formater.formate("1\\\\^er et 2\\\\^e", [])
  "1^er et 2^e"

  # sans correction 
  iex> Pharkdown.Formater.formate("1^ere", [{:correct, false}])
  "1<sup>ere</sup>"

  """
  def juste_pour_definir_la_suivante, do: nil

  def formate(texte, options) when is_binary(texte) do
    # On commence par mettre de côté tous les caractères échappés
    # IO.inspect(texte, label: "\nTexte avant déslashiation")
    %{texte: texte, table: slahed_signs} = capture_slashed_caracters(texte, options)

    # IO.inspect(slahed_signs, label: "\nTable Slahed_signs")

    texte
    # |> IO.inspect(label: "\nTEXTE POUR TRANSFORMATIONS")
    |> formate_simples_styles(options)
    |> formate_href_links(options)
    |> formate_exposants(options)
    # --- /Transformations ---
    # On remet tous les caractères échappé
    |> replace_slashed_caracters(slahed_signs, options)
  end

  @regex_gras_italic ~r/\*\*\*(.+)\*\*\*/U  ; @remp_gras_italic "<strong><em>\\1</em></strong>"
  @regex_graisse ~r/\*\*(.+)\*\*/U          ; @remp_graisse "<strong>\\1</strong>"
  @regex_italics ~r/\*([^ \t].+)\*/U        ; @remp_italics "<em>\\1</em>"
  @regex_underscore ~r/__(.+)__/U           ; @remp_underscore "<u>\\1</u>"
  defp formate_simples_styles(string, _options) do
    string
    |> String.replace(@regex_gras_italic, @remp_gras_italic)
    |> String.replace(@regex_graisse, @remp_graisse)
    |> String.replace(@regex_italics, @remp_italics)
    |> String.replace(@regex_underscore, @remp_underscore)
  end

  @regex_links ~r/\[(?<title>.+)\]\((?<href>.+)(?:\|(?<params>.+))?\)/U
  defp formate_href_links(string, _options) do
    Regex.replace(@regex_links, string, fn _, title, href, params ->
      attributes =
        if params == "" do
          ""
        else
          params
          |> String.split(",") 
          |> Enum.map(fn i -> String.trim(i) end)
          |> Enum.map(fn i -> String.split(i, "=") end)
          |> Enum.map(fn [attr, val] -> "#{attr}=\"#{val}\"" end)
          |> (fn liste -> " " <> Enum.join(liste, " ") end).()
        end
    
      "<a href=\"#{String.trim(href)}\"#{attributes}>#{title}</a>"
    end)
  end

  @regex_exposants ~r/\^(.+)\b/Uu
  @table_remplacement_exposants %{"ere" => "re", "eres" => "res", "eme" => "e", "ème" => "e"}
  defp formate_exposants(string, options) do
    Regex.replace(@regex_exposants, string, fn _tout, found ->
      found = if options[:correct] == false do
        found
      else
        @table_remplacement_exposants[found] || found
      end
      "<sup>#{found}</sup>"
    end)
  end

  defp capture_slashed_caracters(string, _options) do
    Regex.scan(~r/\\(.)/, string)
    |> Enum.with_index()
    |> Enum.reduce(%{texte: string, table: []}, fn {found, index}, accu ->
      [tout, sign] = found
      remp = "SLHSGN#{index}NGSHLS"
      Map.merge(accu, %{
        table: accu.table ++ [sign],
        texte: String.replace(accu.texte, tout, remp, global: false)
      })
    end)
  end

  defp replace_slashed_caracters(texte, [], _options), do: texte
  defp replace_slashed_caracters(texte, slashed_signs, _options) do
    slashed_signs
    |> Enum.with_index()
    |> Enum.reduce(texte, fn {sign, index}, accu ->
      remp = "SLHSGN#{index}NGSHLS"
      String.replace(accu, remp, sign)
    end)
  end

  # ------------ SOUS MÉTHODES ---------------

  defp change_level_in_list(accu, 0, _tag), do: accu

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


end