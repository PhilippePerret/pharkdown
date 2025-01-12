defmodule Pharkdown.Formatter do

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

    iex> Pharkdown.Formatter.formate(:list, [type: :regular, first: 1, content: [[content: "Item 1", level: 1]]], [])
    "<ul><li>Item 1</li></ul>"

    iex> Pharkdown.Formatter.formate(:list, [type: :ordered, first: 1, content: [[content: "Item 1", level: 1]]], [])
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
  iex> Pharkdown.Formatter.formate("*italic* et *autre chose*", [])
  "<em>italic</em> et <em>autre chose</em>"
  # avec parasite
  iex>  Pharkdown.Formatter.formate("*ita\\\\*lic* et *autre chose*", [])
  "<em>ita*lic</em> et <em>autre chose</em>"

  # Gras
  iex> Pharkdown.Formatter.formate("**gras** et **autre gras**", [])
  "<strong>gras</strong> et <strong>autre gras</strong>"
  
  # avec parasite
  iex> Pharkdown.Formatter.formate("**gras** et **autre \\\\*\\\\*gras**", [])
  "<strong>gras</strong> et <strong>autre **gras</strong>"

  # Gras italique
  iex> Pharkdown.Formatter.formate("***gras et italique***", [])
  "<strong><em>gras et italique</em></strong>"

  # Souligné
  iex>  Pharkdown.Formatter.formate("__souligné__ et __très souligné__", [])
  "<u>souligné</u> et <u>très souligné</u>"
  
  # avec parasite
  iex>  Pharkdown.Formatter.formate("__souligné\\\\___ et __très\\\\_\\\\_souligné__", [])
  "<u>souligné_</u> et <u>très__souligné</u>"

  iex> Pharkdown.Formatter.formate("[Mon lien](/vers/un/path)", [])
  "<a href=\\"/vers/un/path\\">Mon lien</a>"
  
  # Avec parasite
  iex> Pharkdown.Formatter.formate("[Mon\\\\]\\\\(lien](/vers/un/path)", [])
  "<a href=\\"/vers/un/path\\">Mon](lien</a>"
  
  # Double
  iex> Pharkdown.Formatter.formate("[Mon lien](/vers/un/path) et [autre lien](path/to)", [])
  "<a href=\\"/vers/un/path\\">Mon lien</a> et <a href=\\"path/to\\">autre lien</a>"

  iex> Pharkdown.Formatter.formate("[Mon autre lien](/vers/un/autre|class=exergue, style=font-size: 12pt)", [])
  "<a href=\\"/vers/un/autre\\" class=\\"exergue\\" style=\\"font-size: 12pt\\">Mon autre lien</a>"

  # -- Exposants ---

  iex> Pharkdown.Formatter.formate("1^er 1^re 1^ere 2^e 3^eme 4^ème 1^res 1^eres note^1 autre note^123a", [])
  "1<sup>er</sup> 1<sup>re</sup> 1<sup>re</sup> 2<sup>e</sup> 3<sup>e</sup> 4<sup>e</sup> 1<sup>res</sup> 1<sup>res</sup> note<sup>1</sup> autre note<sup>123a</sup>"

  # parasite
  iex> Pharkdown.Formatter.formate("1\\\\^er et 2\\\\^e", [])
  "1^er et 2^e"

  # sans correction 
  iex> Pharkdown.Formatter.formate("1^ere", [{:correct, false}])
  "1<sup>ere</sup>"

  # automatique
  iex> Pharkdown.Formatter.formate("XVe XIXe Xeme IXème 2e 1er 1re 1ere 1ère 456e", [])
  "XV<sup>e</sup> XIX<sup>e</sup> X<sup>e</sup> IX<sup>e</sup> 2<sup>e</sup> 1<sup>er</sup> 1<sup>re</sup> 1<sup>re</sup> 1<sup>re</sup> 456<sup>e</sup>"

  # sans correction
  iex> Pharkdown.Formatter.formate("XVe XIXe 1er 456e", [{:correct, false}])
  "XVe XIXe 1er 456e"

  # --- Conservation des code Heex et composants ---

  iex> Pharkdown.Formatter.formate("<% *code non touché* %>", [])
  "<% *code non touché* %>"

  iex> Pharkdown.Formatter.formate("<.composant *composant non touché* />", [])
  "<.composant *composant non touché* />"

  # - code sur plusieurs lignes -
  iex> Pharkdown.Formatter.formate("<%= if *condition* do %>\\n<p>Ce paragraphe __isolé__</p>\\n<% end %>", [])
  "<%= if *condition* do %>\\n<p>Ce paragraphe <u>isolé</u></p>\\n<% end %>"

  # plusieurs (greedy)
  iex> Pharkdown.Formatter.formate("<% eval(4 + @value) %> et <% eval(2 * @value) %>", [])
  "<% eval(4 + @value) %> et <% eval(2 * @value) %>"

  """
  def juste_pour_definir_le_doc_de_la_suivante, do: nil

  def formate(texte, options) when is_binary(texte) do
    # On commence par mettre de côté tous les caractères échappés
    # IO.inspect(texte, label: "\nTexte avant déslashiation")
    %{texte: texte, table: codes_beside} = 
    capture_slashed_caracters(texte, options)
    |> capture_hex_and_composants(options)

    # IO.inspect(slahed_signs, label: "\nTable Slahed_signs")

    texte
    # |> IO.inspect(label: "\nTEXTE POUR TRANSFORMATIONS")
    |> formate_simples_styles(options)
    |> formate_href_links(options)
    |> formate_exposants(options)
    # --- /Transformations ---
    # On remet tous les caractères échappé
    |> replace_codes_beside(codes_beside, options)
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
  @regex_exposants_implicites1 ~r/([XV])(ème|eme|e)/Uu
  # Pas "C" qui traiterait "Ce" ni "M" qui traiterait "Me"
  @regex_exposants_implicites2 ~r/([0-9])(ère|ere|ème|eme|eres|er|re|e)/Uu
  @table_remplacement_exposants %{"ere" => "re", "ère" => "re", "eres" => "res", "eme" => "e", "ème" => "e"}
  defp formate_exposants(string, options) do
    new_string =
    Regex.replace(@regex_exposants, string, fn _tout, found ->
      found = if options[:correct] == false do
        found
      else
        @table_remplacement_exposants[found] || found
      end
      "<sup>#{found}</sup>"
    end)
  
  new_string =
    Regex.replace(@regex_exposants_implicites1, new_string, fn tout, avant, expose ->
      if options[:correct] == false do
        tout
      else
        expose = @table_remplacement_exposants[expose] || expose
        "#{avant}<sup>#{expose}</sup>"
      end
    end)

    Regex.replace(@regex_exposants_implicites2, new_string, fn tout, avant, expose ->
    if options[:correct] == false do
      tout
    else
      expose = @table_remplacement_exposants[expose] || expose
      "#{avant}<sup>#{expose}</sup>"
    end
  end)
  end

  @regex_slashed_signs ~r/\\(.)/
  defp capture_slashed_caracters(string, options) do
    data_besides = %{texte: string, table: [], index: -1, regex: @regex_slashed_signs}
    capture_codes_besides(data_besides, options)
  end

  @regex_code_hex_et_composants ~r/(<[%.](?:.+)[\/%]>)/U
  defp capture_hex_and_composants(data_besides, options) do
    capture_codes_besides(%{data_besides| regex: @regex_code_hex_et_composants}, options)
  end

  defp capture_codes_besides(data_besides, options) do
    if String.match?(data_besides.texte, data_besides.regex) do
      Regex.scan(data_besides.regex, data_besides.texte)
      |> Enum.with_index(data_besides.index + 1)
      |> Enum.reduce(data_besides, fn {found, index}, accu ->
        [tout, sign] = found
        remp = "SLHSGN#{index}NGSHLS"
        Map.merge(accu, %{
          table: accu.table ++ [sign],
          texte: String.replace(accu.texte, tout, remp, global: false),
          index: index
        })
      end)
    else
      data_besides
    end
  end


  @doc """
  Fonction qui, à la fin du formatage du texte, remet les codes mis
  de côté, à commencer par les caractères échappés, les code hex et
  les composants HEX
  """
  defp replace_codes_beside(texte, [], _options), do: texte
  defp replace_codes_beside(texte, slashed_signs, _options) do
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