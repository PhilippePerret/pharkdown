defmodule Pharkdown.Parser do

  # alias Pharkdown.Formatter

  @known_environments [
    "document", "doc", "dictionary", "dico", "dict", "dictionnaire"
  ]
  @environment_substitution %{
    "doc"           => "document",
    "dico"          => "dictionary",
    "dict"          => "dictionary",
    "dictionnaire"  => "dictionary",

  }

  @regex_indentation ~r/^[\t  ]+/um

  @regex_balise_token ~r/^TOKEN([0-9]+)NEKOT$/
  @regex_balise_token_multi ~r/^TOKEN([0-9]+)NEKOT$/m

  @doc """
  Parse le code +string+ pour pouvoir le tokenizer, c'est-à-dire pour
  pouvoir le découper en environnements, listes et paragraphes.


  NOTES
    Bien comprendre que ça n'est pas ici, par exemple, qu'on va 
    traiter les italiques, gras et autres styles. On en traitera pas
    non plus les liens [mon lien](mon href) etc. qui se feront seu-
    lement sur le texte complet dans un second temps.
  """
  def parse(string, options \\ []) when is_binary(string) do
    string
    |> String.replace("\r", "")
    # On supprime toute indentation. L'indentation, dans Pharkdown,
    # est purement visuelle (ce qui est sémantique, puisque ce format
    # n'existe que pour être plus lisible). Voir comment les imbrica-
    # tions sont marquées, avec les listes, par exemple, où c'est le
    # nombre d'astérisques ou de tirets qui déterminent le niveau de
    # liste où on se trouve.
    |> String.replace(@regex_indentation, "")
    # |> String.replace("\n\n+", "\n")
    # NON. Il ne faut surtout pas supprimer ici les doubles 
    # chariots car ils servent par exemple à délimiter les
    # fin de liste.
    # |> IO.inspect(label: "\nTEXTE AVANT TOKENIZE")
    |> tokenize(options)
    # |> IO.inspect(label: "\n<- On revient de parse/2 avec")
  end

  @doc """
  Méthode qui prend un texte en entrée (qui peut être long) et le
  découpe en blocs identifié par des atoms.

  ## Examples

    iex> Pharkdown.Parser.tokenize("Une simple phrase")
    [{:paragraph, [content: "Une simple phrase"]}]

    --- Environnements ---

    iex> Pharkdown.Parser.tokenize("~document\\nPremière ligne\\nDeuxième ligne\\ndocument~\\nAutre paragraphe")
    [
      {:environment, [
          type: :document, 
          content: [
            [type: :paragraph, content: "Première ligne"],
            [type: :paragraph, content: "Deuxième ligne"]
          ]
        ]
      },
      {:paragraph, [content: "Autre paragraphe"]}
    ]

    - Liste -

    iex> Pharkdown.Parser.tokenize("* Premier item\\n* Deuxième item\\n* Troisième item")
    [
      {
        :list, 
        [
          type: :regular, first: nil, 
          content: [
            [content: "Premier item", level: 1], 
            [content: "Deuxième item", level: 1], 
            [content: "Troisième item", level: 1]
          ]
        ]
      }
    ]

    iex> Pharkdown.Parser.tokenize("5- Premier\\n- Deuxième\\n-- Troisième")
    [
      {
        :list, 
        [
          type: :ordered, first: 5, 
          content: [
            [content: "Premier", level: 1], 
            [content: "Deuxième", level: 1], 
            [content: "Troisième", level: 2]
          ]
        ]
      }
    ]

    # --- Liens ---
    # Non, c'est fait sur tout le texte à la fin.

    # --- Mélange ---

    iex> Pharkdown.Parser.tokenize("Tout premier paragraphe\\n# Titre \\n* item 1\\n* item 2\\n\\n## Autre titre\\nParagraphe")
    [
      {:paragraph, [content: "Tout premier paragraphe"]},
      {:title, [content: "Titre", level: 1]},
      {
        :list,  [
          type: :regular, first: nil, 
          content: [
            [content: "item 1", level: 1], 
            [content: "item 2", level: 1]
          ]
        ]
      },
      {:title, [content: "Autre titre", level: 2]},
      {:paragraph, [content: "Paragraphe"]}
    ]

    - Ordre différent -

    iex> Pharkdown.Parser.tokenize("~document\\nLa ligne\\ndocument~\\n## Le sous-titre")
    [
      {:environment, [type: :document, content: [
        [type: :paragraph, content: "La ligne"]
      ]]},
      {:title, [content: "Le sous-titre", level: 2]}
    ]

   
  NOTES
  -----

    N000
      Bien comprendre que les tokens sont ramassés dans le désordre
      dans le texte. On ramasse d'abord les titres, donc ils sont
      placés en premier dans collector.tokens (pas le final, mais le
      collector.tokens intermédiaire) même s'ils sont après d'autres
      choses. C'est la raison pour laquelle on place toutes les 
      marques de token TOKEN<xx>NEKOT dans le texte, pour pouvoir 
      ensuite les passer en revue et mettre les tokens dans l'ordre.

    N001
      Des environnement peuvent se trouver à l'intérieur des listes 
      et doivent être formatés en conséquence. Par exemple :
        * item 1
        ** item 1.2
        doc/
        Un document dans l'item de 
        deuxième niveau
        /doc

  """
  # Voilà comment on s'y prend :
  # 1) on cherche tous les textes reconnaissables (environnement, bloc de
  #    code, titre, liste)
  # 2) on les remplace dans le texte par des 'KNOWN<X>BLOCK' en les 
  #    conservant dans une table.
  # 3) une fois que tout le texte a été analysé, on le parse séquentiellement
  #    pour obtenir une liste de tokens dans l'ordre
  #
  @regex_blockcode ~r/(~~~|```)([a-z]+\n)?(.+)\n\1/ms
  @regex_known_environments ~r/^\~(#{Enum.join(@known_environments, "|")})\n(.+)\n\1\~$/ms

  def tokenize(string, options \\ []) do
    collector = %{texte: string, tokens: [], options: options}
    # IO.inspect(string, label: "\nSTRING AU DÉPART")
    # note : toutes ces fonctions retourne +collector+
    collector
    |> scan_titres_in()
    |> scan_for_known_environments(options)
    # Il faut scanner les listes après les environnements car des 
    # environnements peuvent se trouver dans les listes (cf. N001)
    # |> IO.inspect(label: "\nCOLLECTOR AVANT traitement des listes")
    |> scan_for_list_in()
    # |> IO.inspect(label: "\nCOLLECTOR APRÈS traitement des listes")
    |> scan_for_rest() # tout ce qui reste est considéré comme des paragraphes
    |> reorder_tokens() # on met les tokens dans l'ordre (cf. N000)
    # |> IO.inspect(label: "\nAprès réagencement des tokens")
    |> (fn coll -> coll.tokens end).()
    # collector.tokens contient maintenant la liste ordonnée de tous
    # les tokens qui constituent le texte. On n'a plus besoin du reste.
    # Note : À réfléchir, peut-être qu'à l'avenir il faudrait garder
    # le collector tel quel, pour garder la trace de certains token 
    # qui seraient à l'intérieur de :content d'éléments.
  end


  @doc """
  Méthode générique pour ajouter un token dans le collecteur. La 
  fonction remplace le texte correspond au token dans le texte à 
  traiter et enregistre le token dans la liste des tokens.

  Concrètement, cette méthode : 
    1) définit le nouvel index pour la marque du nouveau token
    2) remplace le texte trouvé dans le texte par la marque du token
    3) ajoute le token AST-like à la liste des tokens
  
    Note : la fonction ajoute toujours l'index courant au +data+
           transmises.
  
  @param collector  Map  Le collecteur (accumulateur) général
  @param type       Atom Le type de token, par exemple :title ou :paragraph
  @param data       List les données propres au token (par exemple
                    le :level pour un titre)
  @param found      Le texte trouvé dans le texte actuel.

  NOTES
    
    N002
      Il faut ne remplacer qu'une seule fois, sinon il y aura des
      problème avec des paragraphes qui peuvent contenir la même
      chose que la chose à remplacer. Cas concret : on a un titre
      `# mon titre'. Si, dans un paragraphe avant ou après on trouve
      le texte `En le mettant avec # mon titre' et bien ce paragraphe
      contiendrait au final un token (celui du titre) qui ne serait
      jamais remplacé ensuite et qui n'aurait aucun sens même rempla-
      cé.
  """ 
  def add_to_collector(collector, type, data, found) do
    # L'index de ce token ajouté
    token_index = Enum.count(collector.tokens)
    remp  = "TOKEN#{token_index}NEKOT"
    ### ATTENTION : ne pas ajouter un retour à la fin, cela fait
    # échouer l'analyse d'un environnement à l'intérieur d'une 
    # liste.
    new_texte = 
      case collector.texte do
      x when is_binary(x) -> 
        #                                            # N002
        String.replace(collector.texte, found, remp, [global: false])
      x when is_list(x) ->
        collector.texte ++ [remp]
      end
    # |> IO.inspect(label: "collector.texte après #{inspect(type)}")

    Map.merge(collector, %{
      texte:  new_texte,
      tokens: collector.tokens ++ [{type, data}]
    })
  end

  @doc """
  ## Description

    Méthode qui parse une ligne de type paragraphe, comme dans un 
    environnement document par exemple pour en tirer, dans son AMORCE
    les éventuels tag, identifiant et classes CSS.

  ## Retour

    Retourne l'item auquel on a pu ajouter :tag, :class et :id
    [type: :paragraphe, content: <contenu textuel>, tag: String, class: [liste], id: String]
    Note : ce retour peut être directement reçu par Pharkdown.Formatter.formate_line

  ## Examples

    // Simple
    iex> Pharkdown.Parser.parse_line([type: :paragraph, content: "Le paragraphe"])
    [type: :paragraph, content: "Le paragraphe"]
    
    // Avec classe CSS
    iex> Pharkdown.Parser.parse_line([type: :paragraph, content: ".moncss: Le paragraphe"])
    [type: :paragraph, content: "Le paragraphe", class: ["moncss"]]

    // Avec deux classes CSS
    iex> Pharkdown.Parser.parse_line([type: :paragraph, content: ".moncss.autrecss: Le paragraphe"])
    [type: :paragraph, content: "Le paragraphe", class: ["moncss", "autrecss"]]

    // Avec identifiant 
    iex> Pharkdown.Parser.parse_line([type: :paragraph, content: "#monPar1: Le paragraphe"])
    [type: :paragraph, content: "Le paragraphe", id: "monPar1"]

    // Avec tag
    iex> Pharkdown.Parser.parse_line([type: :paragraph, content: "matag: Le paragraphe"])
    [type: :paragraph, content: "Le paragraphe", tag: "matag"]

    // Avec class, id et tag
    iex> Pharkdown.Parser.parse_line([type: :paragraph, content: "matag#sonId.css.css3: Le paragraphe"])
    [type: :paragraph, content: "Le paragraphe", tag: "matag", id: "sonId", class: ["css", "css3"]]
  
    // Mal formaté, Id, après Class
    iex> Pharkdown.Parser.parse_line([type: :paragraph, content: ".css#id: Le paragraphe"])
    [type: :paragraph, content: ".css#id: Le paragraphe"]

  """
  @reg_paragraph_line ~r/
  ^
  (?<tag>[a-z]+)?  # soit un tag -- forcément au début
  (?:\#(?<id>[a-zA-Z0-9_\-]+))? # un identifiant
  (?:\.(?<css>[a-z0-9_\-\.]+))?  # des classes CSS
  \:
  (?<content>.+)$/Ux
  def parse_line([type: :paragraph, content: content] = item, _options \\ []) do
    # |> IO.inspect(label: "\nSCAN de #{inspect content}")
    case Regex.named_captures(@reg_paragraph_line, content) do
    nil -> item
    %{"tag" => tag, "id" => id, "css" => css, "content" => content} -> 
      # On les entre dans l'ordre inverse de l'ordre voulu à la fin
      item = []
      item = css != ""  && [{:class, String.split(css, ".")} | item] || item
      item = id  != ""  && [{:id, id}   | item] || item
      item = tag != ""  && [{:tag, tag} | item] || item
      item = [{:content, String.trim(content)} | item]
      [{:type, :paragraph} | item]
    end
  end

  @doc """
  Scan des titres

  ## Examples

    iex> Pharkdown.Parser.tokenize("# Un titre")
    [{:title, [content: "Un titre", level: 1]}]

    iex> Pharkdown.Parser.tokenize("### Un titre de niveau 3")
    [{:title, [content: "Un titre de niveau 3", level: 3]}]

    iex> Pharkdown.Parser.tokenize("####### Un titre de niveau 7")
    [{:title, [content: "Un titre de niveau 7", level: 7]}]

    iex> Pharkdown.Parser.tokenize("######## Mauvais titre de niveau 8")
    [{:paragraph, [content: "######## Mauvais titre de niveau 8"]}]

    iex> Pharkdown.Parser.tokenize("# Un grand titre\\n## Un sous-titre")
    [
      {:title, [content: "Un grand titre", level: 1]},
      {:title, [content: "Un sous-titre", level: 2]},
    ]

  """
  @regex_titres ~r/^(\#{1,7}) (.+)$/m
  def scan_titres_in(collector) do
    case Regex.scan(@regex_titres, collector.texte) do
    nil -> collector
    res -> Enum.reduce(res, collector, fn groupes, collector ->
        [tout, level, contenu] = groupes
        # Données pour le token
        data = [
          content:  String.trim(contenu), 
          level:    String.length(level)
        ]
        add_to_collector(collector, :title, data, tout)
      end)
    end
  end

  # Méthode qui va parser et tokeniser les listes qui se présentent
  # sous la forme "* item" ou "- item" ou "1- item"
  # L'expression recherche :
  #   - un string commençant par "* ", "- " ou "1- "
  #   - et allant jusqu'à une ligne ne contenant pas "\n*" ou "\n-"
  #     ou la fin
  @regex_list ~r/^([0-9]+)?((?:[\*\-]+ .+)(?:\n(?:[\*\-]+ |TOKEN)(?:.+))*)$/mu
  # Ci-dessous, l'explication de l'expression régulière ci-dessus,
  # mais qu'on doit conserver en ligne car mis en x, elle ne fonc-
  # tionne pas comme prévu au niveau des espaces (x doit les suppri-
  # mer ce qui fait que *Un long texte en italique* sur une ligne
  # est considéré comme un item de liste)
  # ^ # un début de ligne
  # ([0-9]+)?     # qui commence peut être par un chiffre pour une
  #               # liste numérotée
  # (             # Pour avoir tout ce qui faut pour trouver ensuite
  #               # les items indépendants
  #   (?:[\*\-]+ .+) # suivi par une ou plusieurs astérisques ou tirets
  #   (?:
  #     \n(?:[\*\-]+ |TOKEN)(?:.+)
  #   )*            # Autant de fois qu on peut en trouver
  # )             # Tous les items -- sans numéro
  # $             # La fin de ligne
  # /xmu
  @reg_list_item ~r/^(?:([\*\-]+) (.+)|TOKEN([0-9]+)NEKOT)$/m
  defp scan_for_list_in(collector) do
    Regex.scan(@regex_list, collector.texte)
    |> Enum.reduce(collector, fn found, coll ->
      # IO.inspect(found, label: "\nFOUND")
      [_tout, index, content] = found
      # Pour une liste numérotée
      type  = (index == "") && :regular || :ordered
      first = (type == :ordered) && String.to_integer(index) || nil
      items = 
        Regex.scan(@reg_list_item, content)
        |> Enum.map(fn found -> 
          # IO.inspect(found, label: "ITEM")
          if Enum.count(found) == 3 do
            [_tout, amorce, contenu] = found
            # Un item de liste
            [content: String.trim(contenu), level: String.length(amorce)]
          else
            [_tout, _amorce, _contenu, index_token_env] = found
            # Un environnement inséré dans la liste
            index_token_env = String.to_integer(index_token_env) - 1
            [content: Enum.at(collector.tokens, index_token_env)]
          end
        end)

      # Si un item est un environnement, on doit le mettre à nil dans
      # la liste des tokens du collector pour qu'il ne soit pas
      # traité (même si je pense que c'est idiot puisque le texte de
      # sa marque de token va automatiquement disparaitre ici et ne
      # sera donc pas recherché au moment du classement des tokens)
      # Pour le moment, je ne fais rien et on verra ensuite s'il faut
      # vraiment le mettre à nil.
      # coll = 
      # items |> Enum.reduce(coll, fn item, souscol -> end)

      data = [
        type:   type,
        first:  first,
        content: items
      ]
      add_to_collector(coll, :list, data, index <> content)
    end)
  end

  # La dernière fonction qui va vraiment renvoyer les tokens,
  # c'est à dire une liste sous la forme :
  # [
  #   {:type, [data]}
  #   {:type, [data]}
  #   {:type, [data]}
  #   etc.
  # ]


  @doc """
  @private
  ## Description

    Fonction de détection et de parse des ENVIRONNEMENTS.

  ## Environnements connus

    // Bloc de code (comme Markdown)
    iex> Pharkdown.Parser.parse("~~~\\nDu code\\nEt du code\\n~~~", [])
    [
      {:environment, [type: :blockcode, language: "", content: "Du code\\nEt du code"]}
    ]

    // Bloc de code (avec backsticks)
    iex> Pharkdown.Parser.parse("```\\nDu code\\nEt du code\\n```", [])
    [
      {:environment, [type: :blockcode, language: "", content: "Du code\\nEt du code"]}
    ]

    // Bloc de code (avec langage)
    iex> Pharkdown.Parser.parse("```elixir\\nDu code\\nEt du code\\n```", [])
    [
      {:environment, [type: :blockcode, language: "elixir", content: "Du code\\nEt du code"]}
    ]

  """
  def scan_for_known_environments(collector, options) do
    Regex.scan(@regex_known_environments, collector.texte)
    # |> IO.inspect(label: "\nAprès SCAN des ENVIRONNEMENTS connus")
    |> Enum.reduce(collector, &treat_known_environment/2)
    |> scan_blockcode_in(options)
  end

  defp scan_blockcode_in(collector, _options) do
    case Regex.scan(@regex_blockcode, collector.texte) do
      nil -> collector
      res -> Enum.reduce(res, collector, fn groupes, collector ->
          [tout, _amorce, langage, contenu] = groupes
          # Données token
          data = [
            type: :blockcode,
            language: String.trim(langage),
            content: String.trim(contenu) 
          ]
          add_to_collector(collector, :environment, data, tout)
        end)
      end
  end

  defp treat_known_environment(found, collector) do
    # IO.puts "-> treat_known_environment(\navec found:#{inspect found}\navec collector: #{inspect collector}\n)"
    [tout, env_name, content] = found
    env_name  = 
    (@environment_substitution[env_name] || env_name)
    |> String.to_atom()

    collector = 
      env_name
      |> treat_content_by_env(content, Map.merge(collector, %{env_content: []}))
    
    data = [
      type: env_name,
      content: collector.env_content
    ]
    add_to_collector(collector, :environment, data, tout)
    # |> IO.inspect(label: "\nCollector après ajout de #{tout}")
  end

  @doc """
  Traitement du contenu d'un dictionnaire
  Le renvoie sous forme de liste de tokens

  # Examples 

    iex> Pharkdown.Parser.parse("~dictionary\\n:Un terme\\nUne définition\\ndictionary~", [])
    [
      {:environment, [
        type: :dictionary,
        content: [
          [type: :term, content: "Un terme"],
          [type: :definition, content: "Une définition"]
        ]
      ]}
    ]
  """
  def treat_content_by_env(:dictionary, content, collector) do
    content
    |> String.split("\n")
    |> Enum.reduce(collector, fn line, accu -> 
      line = String.trim(line)
      cond do
      String.starts_with?(line, ":")  ->
        add_content_to_env_content(String.slice(line, 1..-1//1) |> String.trim(), :term, accu)
      true -> 
        add_content_to_env_content(String.trim(line), :definition, accu)
      end
    end)
  end

  # Pour les doctests, voir __doctests_for_treatment_env_document/0 plus bas
  def treat_content_by_env(:document, content, collector) do
    content
    |> String.split("\n")
    |> Enum.reduce(collector, fn line, accu -> 
      line
      |> String.trim()
      |> add_content_to_env_content(:paragraph, accu) # => accumulateur
    end)
  end


  # Quand environnement non trouvé
  def treat_content_by_env(envname, _content, coll) do
    IO.puts "Environnement inconnu : #{inspect envname}"
    coll
  end


  @doc """
  ## Traitement d'un environnement de type :document

  ## Examples

    iex> Pharkdown.Parser.parse("~document\\nUne ligne de document\\nUne autre ligne\\ndocument~", [])
    [
      {:environment, [type: :document, content: [
        [type: :paragraph, content: "Une ligne de document"], 
        [type: :paragraph, content: "Une autre ligne"]
      ]]}
    ]

  """
  def __doctests_for_treatment_env_document, do: nil
  

  defp add_content_to_env_content(content, type, accu) do
    # IO.puts "-> add_content_to_env_content(\navec content: #{inspect content}\navec type: #{inspect type}\navec collector: #{inspect accu}\n)"
    content   = String.trim(content) # économisera beaucoup d'encre dans les fonctions
    new_content = [type: type, content: content]
    Map.merge(accu, %{
      env_content:  accu.env_content ++ [new_content]
    })
  end

  # Dans cette fonction, on récupère tous les paragraphes sans type
  # particulière (les paragraphes réguliers, normaux)
  defp scan_for_rest(collector) do
    full_ini_texte = collector.texte
    # Pour pouvoir reconstituer le texte
    collector = %{collector | texte: []}

    # On passe en revue tous les paragraphes non traités (sans tokens
    # dans le texte)
    full_ini_texte
    |> String.replace("\n\n+", "\n")
    |> String.split("\n")
    |> Enum.reject(fn x -> x == "" end)
    # |> IO.inspect(label: "\nTexte splité")
    |> Enum.reduce(collector, fn parag, coll -> 
      case String.match?(parag, @regex_balise_token) do
        true ->
          # C'est une balise de token, on la remet telle quelle dans
          # la liste pour le texte.
          # Note : déjà ici, on pourrait reconstituer la fin…
          %{coll | texte: coll.texte ++ [parag]}
        false ->
          # C'est un paragraphe non analysé
          data = [content: parag]
          add_to_collector(coll, :paragraph, data, parag)
        end
    end)
    # À la fin, on remet le texte du collecteur en string
    |> (fn collector -> 
      %{collector | texte: Enum.join(collector.texte, "\n")}
    end).()
    # |> IO.inspect(label: "Fin du scan for rest")
  end


  def reorder_tokens(collector) do
    
    ini_tokens  = collector.tokens
    # |> IO.inspect(label: "\nTous les tokens avant ré-ordonnancement")
    collector   = %{collector | tokens: []}

    # IO.inspect(collector.texte, label: "\nCollector.Texte avant ré-ordonnancemnt")

    # On boucle sur tous les TOKEN<index>NEKOT
    Regex.scan(@regex_balise_token_multi, collector.texte)
    |> Enum.reduce(collector, &remplace_found_tokens_in_collector(&1, &2, ini_tokens))
    # On doit ensuite boucler sur tous les tokens, qui peuvent avoir 
    # des marques de token à l'intérieur. Pour le moment, je voudrais
    # m'en passer, mais il faut voir si ça ne peut pas arriver.
    # Regex.scan(@regex_balise_token_multi, collector.texte)
    # |> Enum.reduce(collector, &remplace_found_tokens_in_collector(&1, &2, ini_tokens))
    # |> IO.inspect(label: "\nCOLLECTOR avec TOKENS RÉ-AGENCÉS")
  end

  defp remplace_found_tokens_in_collector(found, collector, ini_tokens) do
    [_tout, token_index] = found
    token_index = String.to_integer(token_index)
    # IO.inspect(token_index, label: "token_index")
    this_token = Enum.at(ini_tokens, token_index)
    # On remet les tokens dans le bon ordre
    %{ collector | tokens: collector.tokens ++ [this_token] }
  end

end #/module Pharkdown.Parser