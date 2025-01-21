defmodule Pharkdown.Formatter do

  alias Pharkdown.Parser
  alias Transformer, as: T

  @doc """

  Formatage d'une simple ligne (par exemple un paragraphe régulier).
  On formate aussi bien l'intérieur de la balise (id, class, tag 
  même) que le contenu (italiques, liens, etc.).

  ## Description

    La méthode est le plus souvent appelée à la suite de 
    Parser.parse_line/2 qui tranforme un paragraphe en quelque chose
    comme [type: :paragraph, content: "<contenu>", tag: "tag", 
    id: "id", class: ["liste", "classes", "CSS"]]

    Elle retourne le texte mis en forme pour inscription dans le 
    document de la page. Elle corrige donc aussi tout ce qui peut
    être corrigé dans un texte, italiques, liens, exposants, etc.

  ## Examples

    // Simple paragraphe
    iex> Pharkdown.Formatter.formate_line([type: :paragraph, content: "Mon simple paragraphe."])
    ~s(<div class="p">Mon simple paragraphe.</div>)

    // Paragraphe avec 1 classe css
    iex> Pharkdown.Formatter.formate_line([type: :paragraph, content: "Mon simple paragraphe.", class: ["maClasse"]])
    ~s(<div class="p maClasse">Mon simple paragraphe.</div>)
  
    // Paragraphe avec 2 classes css
    iex> Pharkdown.Formatter.formate_line([type: :paragraph, content: "Mon simple paragraphe.", class: ["maClasse", "autre-classe"]])
    ~s(<div class="p maClasse autre-classe">Mon simple paragraphe.</div>)
  
    // Paragraphe avec identifiant
    iex> Pharkdown.Formatter.formate_line([type: :paragraph, content: "Mon simple paragraphe.", id: "monPar"])
    ~s(<div id="monPar" class="p">Mon simple paragraphe.</div>)

    // Paragraphe avec tag spéciale
    iex> Pharkdown.Formatter.formate_line([type: :paragraph, content: "Mon simple paragraphe.", tag: "latag"])
    ~s(<latag class="p">Mon simple paragraphe.</latag>)

    // Paragraphe avec tag spéciale, id et classes css
    iex> Pharkdown.Formatter.formate_line([type: :paragraph, content: "Mon simple paragraphe.", tag: "latag", id: "monPar", class: ["class1", "class2"]])
    ~s(<latag id="monPar" class="p class1 class2">Mon simple paragraphe.</latag>)

    // Test avec de l'italique et de l'insécable
    iex> Pharkdown.Formatter.formate_line([type: :paragraph, content: "Mon *simple* paragraphe !", id: "parWithItal"])
    ~s(<div id="parWithItal" class="p">Mon <em>simple</em> <nowrap>paragraphe&nbsp;!</nowrap></div>)
    
  """
  def formate_line(item, options \\ []) do
    tag       = item[:tag] || "div"
    maybe_id  = item[:id] && " id=\"#{item[:id]}\"" || ""
    maybe_css = item[:class] && " #{Enum.join(item[:class]," ")}" || ""

    # On corrige le contenu avec la grande fonction de correction
    contenu = formate(item[:content], options)

    "<#{tag}#{maybe_id} class=\"p#{maybe_css}\">#{contenu}</#{tag}>"
  end

  @doc """
  Fonction principale qui reçoit le découpage en tokens de la fonction
  Pharkdown.Parser.parse et le met en forme.
  """
  def formate(liste, options) when is_list(liste) do
    liste
    # |> IO.inspect(label: "\nLISTE")
    |> Enum.map(fn {type, data} -> 
      # IO.inspect(type, label: "Type du token")
      # IO.inspect(data, label: "Data du token")
      case type do
      :environment -> formate(data[:type], data, options)
      _ -> formate(type, data, options) 
      end
    end)
    |> Enum.join("\n")
  end

  # Les tests de cette (grosse) fonction sont définis avant la
  # fonction virtuelle :__tests_pour_formate_texte_generale
  def formate(texte, options) when is_binary(texte) do
    # On commence par mettre de côté tous les caractères échappés
    # IO.inspect(texte, label: "\nTexte avant déslashiation")
    %{texte: texte, table: codes_beside} = 
    capture_slashed_caracters(texte, options)
    |> capture_hex_and_composants(options)
    |> capture_codes(options)
    # |> IO.inspect(label: "\nAprès capture des codes")

    # IO.inspect(slahed_signs, label: "\nTable Slahed_signs")

    texte
    # |> IO.inspect(label: "\nTEXTE POUR TRANSFORMATIONS")
    |> treate_custom_pre_functions(options)
    |> formate_smart_guillemets(options)
    |> pose_anti_wrappers(options)
    |> formate_simples_styles(options)
    |> formate_href_links(options)
    |> formate_exposants(options)
    # --- /Transformations ---
    # On remet tous les caractères échappés
    # |> IO.inspect(label: "Avant de remettre les codes de côté")
    |> replace_codes_beside(codes_beside, options)
    # |> IO.inspect(label: "Après avoir remis les codes de côté")
    |> treate_custom_post_functions(options)
  end

  def formate(:paragraph, data, options) do
    [{:type, :paragraph} | data]
    |> Parser.parse_line(options)
    |> formate_line(options)
  end

  # Une ligne de code à garder telle quelle
  def formate(:eex_line, data, _options) do
    "<%#{data[:content]}%>"
  end

  def formate(:title, data, _options) do
    "<h#{data[:level]}>#{data[:content]}</h#{data[:level]}>"
  end

  def formate(:blockcode, data, _options) do
    "<pre><code lang={{GL}}#{data[:language]}{{GL}}>\n" <> (
      data[:content] |> T.h(:less_than)
    ) <> "\n</code></pre>"
    # |> IO.inspect(label: "Retourné par formate(:blockcode ...)")
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


  def formate(:line_hr, data, _options) do
    params = data[:params]
    params = cond do
      is_nil(params) 
        -> "" 
      is_binary(params) and String.starts_with?(params, ".") 
        -> ~s( class="#{StringTo.class_list(params)|> Enum.join(" ")}")
      is_binary(params) 
        -> ~s( style="#{params}")
      is_map(params) ->
        params =
          Enum.map(params, fn {k, v} ->
            v = cond do
              is_binary(v) -> v
              is_map(v) -> v.raw_value
            end
            "#{k}:#{v};" 
          end) |> Enum.join("")
        ~s( style="#{params}")
      end
    "<hr#{params}/>"
  end

  # Formatage du type dictionary
  # ----------------------------
  # Pour les tests, cf. la fonction doctests_pour_formate_dictionary/0
  def formate(:dictionary, data, options) do
    # IO.puts("-> formate(:dictionary\navec data: #{inspect data})")
    "<dl>" <> (data[:content]
    |> Enum.map(fn par ->
      formate_dict_element(par[:type], par[:content]|>formate(options))
    end)
    |> Enum.join("")) <> "</dl>"
  end

 
  def formate(:document, data, options) do
    "<section data-env={{GL}}document{{GL}} class={{GL}}document{{GL}}>" <> (
      Enum.map(data[:content], fn item ->
        item 
        |> Parser.parse_line(options) 
        |> formate_line(options)
      end)
      |> Enum.join("")
    ) <> "</section>"
  end

  # Formatage quelconque, non défini
  def formate(type, _data, _options) do
    raise "Je ne sais pas encore traiter le type #{type}"
  end


  @doc """
  FONCTION PRINCIPALE 
  qui reçoit le texte produit par la fonction précédente et le 
  finalise. C'est ici par exemple que sont traités les *italic* et
  autres **gras** ainsi que les [lien](vers/quelque/chose)

  ## Examples

    // --- Conservation des échappés ---

    iex> Pharkdown.Formatter.formate("\\\—un texte\\\— un \\\\*un texte\\\\* et \\\\n pour voir.", [])
    "—un texte— un *un texte* et \\\\n pour voir."

    // --- Stylisation générale ---

    // Italiques
    iex> Pharkdown.Formatter.formate("*italic* et *autre chose*", [])
    "<em>italic</em> et <em>autre chose</em>"

    // avec parasite (caractère échappé à ne pas considérer)
    iex>  Pharkdown.Formatter.formate("*ita\\\\*lic* et *autre chose*", [])
    "<em>ita*lic</em> et <em>autre chose</em>"

    // Gras
    iex> Pharkdown.Formatter.formate("**gras** et **autre gras**", [])
    "<strong>gras</strong> et <strong>autre gras</strong>"
    
    // avec parasite
    iex> Pharkdown.Formatter.formate("**gras** et **autre \\\\*\\\\*gras**", [])
    "<strong>gras</strong> et <strong>autre **gras</strong>"

    // Gras italique
    iex> Pharkdown.Formatter.formate("***gras et italique***", [])
    "<strong><em>gras et italique</em></strong>"

    // Souligné
    iex>  Pharkdown.Formatter.formate("__souligné__ et __très souligné__", [])
    "<u>souligné</u> et <u>très souligné</u>"
    
    // avec parasite
    iex>  Pharkdown.Formatter.formate("__souligné\\\\___ et __très\\\\_\\\\_souligné__", [])
    "<u>souligné_</u> et <u>très__souligné</u>"

    // Lien
    iex> Pharkdown.Formatter.formate("[Mon lien](/vers/un/path)", [])
    "<a href=\\"/vers/un/path\\">Mon lien</a>"
    
    // Avec parasite
    iex> Pharkdown.Formatter.formate("[Mon\\\\]\\\\(lien](/vers/un/path)", [])
    "<a href=\\"/vers/un/path\\">Mon](lien</a>"
    
    // Double lien
    iex> Pharkdown.Formatter.formate("[Mon lien](/vers/un/path) et [autre lien](path/to)", [])
    "<a href=\\"/vers/un/path\\">Mon lien</a> et <a href=\\"path/to\\">autre lien</a>"

    // Lien avec style
    iex> Pharkdown.Formatter.formate("[Mon autre lien](/vers/un/autre|class=exergue, style=font-size: 12pt)", [])
    "<a href=\\"/vers/un/autre\\" class=\\"exergue\\" style=\\"font-size: 12pt\\">Mon autre lien</a>"

    - Lien avec route vérifiée

    iex> Pharkdown.Formatter.formate("[lien route vérifiée]({/path/to/verified/route})", [])
    ~s(<a href={~p"/path/to/verified/route"}>lien route vérifiée</a>)

    // -- Exposants ---

    iex> Pharkdown.Formatter.formate("1^er 1^re 1^ere 2^e 3^eme 4^ème 1^res 1^eres note^1 autre note^123a", [])
    "1<sup>er</sup> 1<sup>re</sup> 1<sup>re</sup> 2<sup>e</sup> 3<sup>e</sup> 4<sup>e</sup> 1<sup>res</sup> 1<sup>res</sup> note<sup>1</sup> autre note<sup>123a</sup>"

    // parasite
    iex> Pharkdown.Formatter.formate("1\\\\^er et 2\\\\^e", [])
    "1^er et 2^e"

    // Options : sans correction
    iex> Pharkdown.Formatter.formate("1^ere", [{:correct, false}])
    "1<sup>ere</sup>"

    // Corrections automatiques
    iex> Pharkdown.Formatter.formate("XVe XIXe Xeme IXème 2e 1er 1re 1ere 1ère 456e", [])
    "XV<sup>e</sup> XIX<sup>e</sup> X<sup>e</sup> IX<sup>e</sup> 2<sup>e</sup> 1<sup>er</sup> 1<sup>re</sup> 1<sup>re</sup> 1<sup>re</sup> 456<sup>e</sup>"

    // Options : sans correction
    iex> Pharkdown.Formatter.formate("XVe XIXe 1er 456e", [{:correct, false}])
    "XVe XIXe 1er 456e"

    // --- Conservation des code Heex et composants ---

    iex> Pharkdown.Formatter.formate("<% *code non touché* %>", [])
    "<% *code non touché* %>"

    iex> Pharkdown.Formatter.formate("<.composant *composant non touché* />", [])
    "<.composant *composant non touché* />"

    // - code EEX sur plusieurs lignes -
    iex> Pharkdown.Formatter.formate("<%= if *condition* do %>\\n<p>Ce paragraphe __isolé__</p>\\n<% end %>", [])
    "<%= if *condition* do %>\\n<p>Ce paragraphe <u>isolé</u></p>\\n<% end %>"

    // plusieurs (greedy)
    iex> Pharkdown.Formatter.formate("<% eval(4 + @value) %> et <% eval(2 * @value) %>", [])
    "<% eval(4 + @value) %> et <% eval(2 * @value) %>"

    // Code dans des backsticks
    iex> Pharkdown.Formatter.formate("`du code`", [])
    "<code>du code</code>"

    // Le code ne doit pas être touché
    iex> Pharkdown.Formatter.formate("`nocss: pas *italique* non plus`", [])
    "<code>nocss: pas *italique* non plus</code>"

    // Plusieurs codes
    iex> Pharkdown.Formatter.formate("`un code` et puis `un autre code`", [])
    "<code>un code</code> et puis <code>un autre code</code>"
  """
  def __doctests_pour_formate_texte_generale, do: nil

  @doc """
  @private

  ## Description

    Traitement de l'environnement document. Pour le moment, on ne 
    fait que mettre en forme les paragraphes. plus tard, il y aura
    certainement d'autres traitement, peut-être les formateurs de
    texte.

  """
  def doctests_de_formate_document, do: nil

  @doc """
  Tests pour la méthode formate/3 pour un dictionnaire

  ## Example
  
    iex> Pharkdown.Formatter.formate(:dictionary, [type: :dictionary, content: [[type: :term, content: "Un terme à expliquer"], [type: :definition, content: "La définition du terme."]]], [])
    "<dl><dt>Un terme à expliquer</dt><dd>La définition du terme.</dd></dl>"

    - L'intérieur d'un dictionnaire est corrigé correctement
    iex> Engine.compile_string("~dictionary\\n:Un [lien]({vers/verified/route})\\nLa *définition* pour --voir//contrôler--.\\ndictionary~")
    ~s(<dl><dt>Un <a href={~p"/vers/verified/route"}>lien</a></dt><dd>La <em>définition</em> pour <del>voir</del> <ins>contrôler</ins>.</dd></dl>)
  
  """  
  def doctests_pour_formate_dictionary, do: nil

  defp formate_dict_element(:term, content), do: "<dt>#{content}</dt>"
  defp formate_dict_element(:definition, content), do: "<dd>#{content}</dd>"

  @doc """
  ## Traitement des guillemets droits

  ## Examples

    iex> Formatter.formate_smart_guillemets(~s("bonjour"), [])
    "« bonjour »"

    iex> Formatter.formate_smart_guillemets(~s("bonjour" et "re-bonjour"), [])
    "« bonjour » et « re-bonjour »"

    - On ne touche à rien si :smarties est à false
    iex> Formatter.formate_smart_guillemets(~s("bonjour" et "re-bonjour"), [smarties: false])
    ~s("bonjour" et "re-bonjour")

    - On ne touche pas aux guillemets sans au moins un 'blanc' autour
    iex> Formatter.formate_smart_guillemets(~s(<span class="height:12px;">solide</span>), [])
    ~s(<span class="height:12px;">solide</span>)

    - Avec des guillemets à transformer et d'autres non
    iex> Formatter.formate_smart_guillemets(~s("bonjour" et >style="height:12x;">), [])
    ~s(« bonjour » et >style="height:12x;">)

    - Sauf si l'on n'a rien à corriger
    iex> Formatter.formate_smart_guillemets(~s("bonjour" et >style="height:12x;">), [smarties: false])
    ~s("bonjour" et >style="height:12x;">)

  """
  @regex_guillemets ~r/(?:(^| | )")(.+)(?:"( | |$))/U ; @rempl_guillemets "\\1« \\2 »\\3"
  # Avant (mais trop imprécis) @regex_guillemets ~r/"(.+)"/U   ; 
  @regex_apostrophes ~r/'/U       ; @rempl_apostrophes "’"
  def formate_smart_guillemets(string, options) do
    if options[:smarties] == false do
      string
    else
      string
      |> String.replace(@regex_guillemets, @rempl_guillemets)
      |> String.replace(@regex_apostrophes, @rempl_apostrophes)
    end
  end

  @doc """
  Pose des anti-wrappers sur les textes.

  ## Explication

    Même avec l'utilisation d'insécables ou de '&amp;nbsp;', des 
    signes (comme des ponctuations) peuvent se retrouver à la ligne.
    Pour empêcher ce comportement de façon définitive, on entoure les
    texte "insécables" de <nowrap>...</nowrap> qui est une balise 
    spéciale qui possède la propriété white-space à nowrap (d'où son
    nom).
    La méthode ci-dessous est chargée de cette opération.

    Noter qu'elle intervient après que les guillemets ont été (ou 
    non) remplacés par des chevrons. Elle s'assure également que 
    tous les insécables aient été placés (même avec les chevrons car
    ils ont pu être mis par l'utilisateur)

  ## Examples

    // Sans rien, ne change rien
    iex> Pharkdown.Formatter.pose_anti_wrappers("bonjour tout le monde")
    "bonjour tout le monde"

    // Mot unique, simple guillemets sans insécables
    iex> Pharkdown.Formatter.pose_anti_wrappers("« bonjour »")
    T.h "<nowrap>« bonjour »</nowrap>"
    
    // Deux mots, simple guillemets sans insécables
    iex> Pharkdown.Formatter.pose_anti_wrappers("« bonjour vous »")
    T.h "<nowrap>« bonjour</nowrap> <nowrap>vous »</nowrap>"

    // Plusieurs mots, simples guillemets sans insécables
    iex> Pharkdown.Formatter.pose_anti_wrappers("« bonjour à tous »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous »</nowrap>"

    iex> Pharkdown.Formatter.pose_anti_wrappers("bonjour !")
    T.h "<nowrap>bonjour !</nowrap>"

    iex> Pharkdown.Formatter.pose_anti_wrappers("bonjour !?!")
    T.h "<nowrap>bonjour !?!</nowrap>"

    iex> Pharkdown.Formatter.pose_anti_wrappers("bonjour vous !")
    T.h "bonjour <nowrap>vous !</nowrap>"

    iex> Pharkdown.Formatter.pose_anti_wrappers("bonjour vous !?")
    T.h "bonjour <nowrap>vous !?</nowrap>"

    iex> Pharkdown.Formatter.pose_anti_wrappers("« bonjour à tous ! »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous ! »</nowrap>"
    
    iex> Pharkdown.Formatter.pose_anti_wrappers("« bonjour à tous !?! »")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous !?! »</nowrap>"
    
    
    iex> Pharkdown.Formatter.pose_anti_wrappers("« bonjour à tous » !")
    T.h "<nowrap>« bonjour</nowrap> à <nowrap>tous » !</nowrap>"

  """

  # Pour insécables simples manquantes
  @regex_req_insec_before_ponct ~r/ ([!?:;])/
  @rempl_req_insec_before_poncts " \\1"
  # Pour insécables manquantes entre tirets (penser qu'il peut y en 
  # avoir quand même une de placée, d'où l'utilisation de [  ] au 
  # lieu de l'espace seule)
  @regex_req_insec_in_cont ~r/([—–«])[  ](.+)[  ]([»—–])/Uu
  @rempl_req_insec_in_cont "\\1 \\2 \\3"
  # Le cas le plus complexe, où l'on peut avoir guillemets + tirets +
  # ponctuations doubles, dans tous les sens, c'est-à-dire aussi bien :
  #   — « bonjour à tous » ! —
  #   — « bonjour à tous » — !
  #   « — bonjour à tous » ! —  -- fautif, quand même
  #   « bonjour — à — tous ! »
  #   « bonjour — à tous — » !
  # Le seul cas qu'on envisage pas ici, c'est le cas de chevrons 
  # imbriqués dans des chevrons, qui est une faute.
  @regex_insecable_guils ~r/([—–«] )?([—–«] )(.+?)( [—–!?:;»]+)( [—–!?:;»]+)?( [—–!?:;»]+)?/u
  @regex_insecable_tirets ~r/([—–])[  ](.+)[  ]([—–])/Uu
  @regex_insecable_ponct ~r/([^ ]+) ([!?:;]+?)/Uu   ; @rempl_insecable_ponct "<nowrap>\\1&nbsp;\\2</nowrap>"
  def pose_anti_wrappers(string, options \\ []) do
    string
    # On doit commencer par mettre des espaces insécables là où
    # ils manquent
    |> String.replace(@regex_req_insec_before_ponct, @rempl_req_insec_before_poncts)
    |> String.replace(@regex_req_insec_in_cont, @rempl_req_insec_in_cont)
    # Ensuite on traite tous les cas d'insécables imbriqués
    |> string_replace(@regex_insecable_guils, &antiwrappers_guils_et_autres/7, options)
    # |> string_replace(@regex_insecable_guils, options)
    |> string_replace(@regex_insecable_tirets, options)
    |> String.replace(@regex_insecable_ponct, @rempl_insecable_ponct)
  end

  # Fonction traitant les anti-wrappers sur les strings avec guillemets
  # Elle permet d'utiliser Regex.replace dans un pipe de strings
  defp string_replace(string, regex, callback, _options) do
    Regex.replace(regex, string, callback)
  end

  defp antiwrappers_guils_et_autres(tout, arg1, arg2, inner_guils, arg3, arg4, arg5) do
    # Le principe simple est le suivant : si +inner_guils+ contient 
    # un seul mot, on met le nowrap autour de tout, alors que s'il y
    # en a plusieurs, on ne prend que le dernier.
    inner_guils = String.split(inner_guils, " ")
    cond do
    Enum.count(inner_guils) == 1 -> 
      "<nowrap>#{tout}</nowrap>"
    Enum.count(inner_guils) == 2 -> 
      [first_mot, last_mot] = inner_guils
      "<nowrap>#{arg1}#{arg2}#{first_mot}</nowrap> <nowrap>#{last_mot}#{arg3}#{arg4}#{arg5}</nowrap>"
    true ->
      {first_mot, reste}  = List.pop_at(inner_guils, 0)
      {last_mot, reste}   = List.pop_at(reste, -1)
      reste = Enum.join(reste, " ")
      "<nowrap>#{arg1}#{arg2}#{first_mot}</nowrap> #{reste} <nowrap>#{last_mot}#{arg3}#{arg4}#{arg5}</nowrap>"
    end 
    |> String.replace(~r/ /, "&nbsp;")
  end
  
  # Méthode "détachée" permettant de placer les anti-wrappers sur les
  # String en tenant compte du nombre de mots.
  defp string_replace(string, regex, _options) do
    if String.match?(string, regex) do
      Regex.replace(regex, string, fn _tout, tbefore, content, tafter ->
        founds = String.split(content, " ")
        if Enum.count(founds) > 1 do
          # Contenu de plusieurs mot
          {first, founds} = List.pop_at(founds, 0)
          {last, founds}  = List.pop_at(founds, -1)
          reste = 
            if Enum.any?(founds) do
              " " <> Enum.join(founds, " ") <> " "
            else
              " "
            end
          "<nowrap>#{tbefore} #{first}</nowrap>#{reste}<nowrap>#{last} #{tafter}</nowrap>"
        else
          # Contenu d'un seul mot
          "<nowrap>#{tbefore} #{content} #{tafter}</nowrap>"
        end
      end)
    else
      string
    end
  end

  @doc """
  Formatage des styles simples

  ## Examples

    - Les italiques avec *italiques*
    iex> Formatter.formate_simples_styles("*italique*", [])
    "<em>italique</em>"

    - Les gras avec **gras**
    iex> Formatter.formate_simples_styles("**gras**", [])
    "<strong>gras</strong>"

    - Les insertions/suppressions avec --supp//add--
    iex> Formatter.formate_simples_styles("--supprimer//corrigé-- --sup//ins--", [])
    "<del>supprimer</del> <ins>corrigé</ins> <del>sup</del> <ins>ins</ins>"

  """
  @regex_gras_italic ~r/\*\*\*(.+)\*\*\*/U  ; @rempl_gras_italic "<strong><em>\\1</em></strong>"
  @regex_graisse ~r/\*\*(.+)\*\*/U          ; @rempl_graisse "<strong>\\1</strong>"
  @regex_italics ~r/\*([^ \t].+)\*/U        ; @rempl_italics "<em>\\1</em>"
  @regex_underscore ~r/__(.+)__/U           ; @rempl_underscore "<u>\\1</u>"
  @regexp_del_ins ~r/\-\-(.+)\/\/(.+)\-\-/U ; @rempl_del_ins "<del>\\1</del> <ins>\\2</ins>"
  def formate_simples_styles(string, _options) do
    string
    |> String.replace(@regexp_del_ins, @rempl_del_ins)
    |> String.replace(@regex_gras_italic, @rempl_gras_italic)
    |> String.replace(@regex_graisse, @rempl_graisse)
    |> String.replace(@regex_italics, @rempl_italics)
    |> String.replace(@regex_underscore, @rempl_underscore)
  end

  @doc """

  ## Examples

    iex> Pharkdown.Formatter.formate("[Un titre de lien](path/to/destination)", [])
    "<a href=\\"path/to/destination\\">Un titre de lien</a>"

    // Avec un protocole, on met toujours une tarkeg _blank
    iex> Pharkdown.Formatter.formate("[Lien externe](http://www.vers/lien/externe)", [])
    "<a href=\\"http://www.vers/lien/externe\\" target=\\"_blank\\">Lien externe</a>"

    // Avec des paramètres, les ajoute en attributs
    iex> Pharkdown.Formatter.formate("[lien stylé](path/to/lien|class=cssclass)", [])
    "<a href=\\"path/to/lien\\" class=\\"cssclass\\">lien stylé</a>"

    - Liens de route vérifiée

    iex> Pharkdown.Formatter.formate("[lien]({route/verified})", [])
    ~s(<a href={~p"/route/verified"}>lien</a>)

    iex> Pharkdown.Formatter.formate("[lien]({/route/verified})", [])
    ~s(<a href={~p"/route/verified"}>lien</a>)

    iex> Pharkdown.Formatter.formate("[lien]({~p/route/verified})", [])
    ~s(<a href={~p"/route/verified"}>lien</a>)

  """
  def __pour_le_doctest_de_la_fonction_href_links, do: nil

  @doc """
  Formatage des liens [titre](url|properties)

  ## Examples

    (voir aussi les exemples ci-dessus)

    iex> Pharkdown.Engine.compile_string("[mon lien]({explorer/tasker})")
    ~s(<div class="p"><a href={~p"/explorer/tasker"}>mon lien</a></div>)

  """
  def formate_href_links(string, _options) do
    Pharkdown.Link.treate_links_in(string)
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


  @regex_slashed_signs ~r/\\([^n])/
  defp capture_slashed_caracters(string, options) do
    data_besides = %{texte: string, table: [], index: -1, regex: @regex_slashed_signs}
    capture_codes_besides(data_besides, options)
  end

  @regex_code_hex_et_composants ~r/(<[%.](?:.+)[\/%]>)/U
  defp capture_hex_and_composants(data_besides, options) do
    capture_codes_besides(%{data_besides| regex: @regex_code_hex_et_composants}, options)
  end

  @regex_codes_backsticks ~r/\`(.+)\`/Uu
  defp capture_codes(data_besides, options) do
    capture_codes_besides(%{data_besides| regex: @regex_codes_backsticks}, [ {:before, "<code>"}, {:after, "</code>"} | options])
  end

  defp capture_codes_besides(data_besides, options) do
    # IO.inspect(data_besides.texte, label: "\nTEXTE")
    # IO.inspect(options, label: "OPTIONS")
    if String.match?(data_besides.texte, data_besides.regex) do
      before = options[:before] || ""
      tafter = options[:after]  || ""
      Regex.scan(data_besides.regex, data_besides.texte)
      |> Enum.with_index(data_besides.index + 1)
      |> Enum.reduce(data_besides, fn {found, index}, accu ->
        [tout, sign] = found
        remp = "SLHSGN#{index}NGSHLS"
        Map.merge(accu, %{
          table: accu.table ++ [before <> sign <> tafter],
          texte: String.replace(accu.texte, tout, remp, global: false),
          index: index
        })
      end)
    else
      data_besides
    end
  end
  
  # Fonction qui, à la fin du formatage du texte, remet les codes mis
  # de côté, à commencer par les caractères échappés, les code hex et
  # les composants HEX
  @regex_code_beside ~r/SLHSGN(?<index>[0-9]+)NGSHLS/
  defp replace_codes_beside(texte, [], _options), do: texte
  defp replace_codes_beside(texte, slashed_signs, _options) do
    slashed_signs
    |> Enum.with_index()
    |> Enum.reduce(texte, fn {sign, index}, accu ->
      remp = "SLHSGN#{index}NGSHLS"
      # Ici, dans sign, il peut y avoir des codes mis de côté
      sign = if Regex.match?(@regex_code_beside, sign) do
        %{"index" => index} = Regex.named_captures(@regex_code_beside, sign)
        search = "SLHSGN#{index}NGSHLS"
        index = String.to_integer(index)
        srempl = Enum.at(slashed_signs, index)
        String.replace(sign, search, srempl, [global: false])
      else sign end
      String.replace(accu, remp, sign, [global: false])
    end)
  end

  @doc """
  Fonction qui traite les fonctions utilisateurs dans le code initial
  du fichier. 
  Note : Ça NE se passe PLUS en tout début, avant le parsing du
  code, car alors toutes les fonctions, même dans les codes EEx ou les
  blocs de code, seraient traitées.

  Notes
    - Voir aussi les fonctions sur une ligne qui sont traités par le
      parser pour ne pas être considérées comme des paragraphes.
    - Si une fonction doit être évaluée seulement à la fin, il faut 
      lui mettre "post/" devant son nom.
  """
  @regex_custom_pre_functions ~r/(?<!post\/)\b([a-z_]+)\((.*)\)/U
  def treate_custom_pre_functions(string, options) do
    treate_custom_functions(string, @regex_custom_pre_functions, options)
  end
  @regex_custom_post_functions ~r/post\/([a-z_]+)\((.*)\)/U
  def treate_custom_post_functions(string, options) do
    treate_custom_functions(string, @regex_custom_post_functions, options)
  end
  def treate_custom_functions(string, regex, _options) do
    if Regex.match?(regex, string) do
      Regex.scan(regex, string)
      |> Enum.reduce(string, fn found, string -> 
        [tout, fun_name, fun_params] = found
        fun_params = cond do
          fun_params == "" -> []
          fun_params =~ ~r/^\[(.+)\]$/ -> [StringTo.list(fun_params)]
          true -> StringTo.list(fun_params)
          end
        fun_name = String.to_atom(fun_name)
        module = 
          if function_exported?(Pharkdown.Helpers, fun_name, Enum.count(fun_params)) do
            Pharkdown.Helpers
          else
            Pharkdown.PharkdownHelpers
          end

        rempl = apply(module, fun_name, fun_params)
        String.replace(string, tout, rempl, [global: false])
      end)
    else
      string
    end
  end

  @doc """
  @private

  ## Description
  
    Les toutes dernières corrections. C'est ici par exemple qu'on
    remplace les \n par des <br /> (note : ce qui pourrait être fait
    avant, maintenant que le caractère n'est plus mis de côté, mais

  ## Corrections finales effectuées

    - \n -> <br >
    iex> Pharkdown.Formatter.very_last_correction("\\\\n", [])
    "<br />"

    - {{GL}} -> "
    iex> Pharkdown.Formatter.very_last_correction("class={{GL}}css{{GL}}", [])
    "class=\\"css\\""

  bon…)
  """
  @regex_returns ~r/( +)?\\n( +)?/    ; @rempl_returns "<br />"
  @regex_protected_guils ~r/\{\{GL\}\}/ ; @rempl_protected_guils "\""
  def very_last_correction(string, _options) do
    # IO.inspect(string, label: "[very_last_correction] String au début")
    string
    |> String.replace(@regex_returns, @rempl_returns)
    |> String.replace(@regex_protected_guils, @rempl_protected_guils)
    # |> IO.inspect(label: "[very_last_correction] String à la fin")
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