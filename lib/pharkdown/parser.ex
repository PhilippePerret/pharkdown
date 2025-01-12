defmodule Pharkdown.Parser do

  # alias Pharkdown.Formater

  @known_environments [
    "document", "doc", "blockcode", "bcode"
  ]
  @environment_substitution %{
    "doc"   => "document",
    "bcode" => "blockcode",
    "code"  => "code",
  }

  @regex_balise_token ~r/^TOKEN_([0-9]+)_TOKEN$/
  @regex_balise_token_multi ~r/^TOKEN_([0-9]+)_TOKEN$/m

  @doc """
  Parse le code +string+


  NOTES
    Bien comprendre que ça n'est pas ici, par exemple, qu'on va 
    traiter les italiques, gras et autres styles. On en traitera pas
    non plus les liens [mon lien](mon href) etc. qui se feront seu-
    lement sur le texte complet dans un second temps.
  """
  def parse(string, options \\ []) when is_binary(string) do
    string
    |> String.replace("\r", "")
    # |> String.replace("\n\n+", "\n")
          # NON. Il ne faut surtout pas supprimer ici les doubles 
          # chariots car ils servent par exemple à délimiter les
          # fin de liste.
    |> tokenize(options)
    # |> IO.inspect(label: "\n<- parse avec")
  end

  @doc """
  Méthode qui prend un texte en entrée (qui peut être long) et le
  découpe en blocs identifié par des atoms.

  ## Examples

    iex> Pharkdown.Parser.tokenize("Une simple phrase")
    [{:paragraph, [index: 1, content: "Une simple phrase"]}]

    iex> Pharkdown.Parser.tokenize("# Un titre simple")
    [{:title, [index: 1, content: "Un titre simple", level: 1]}]

    iex> Pharkdown.Parser.tokenize("# Un grand titre\\n## Un sous-titre")
    [
      {:title, [index: 1, content: "Un grand titre", level: 1]},
      {:title, [index: 2, content: "Un sous-titre", level: 2]},
    ]

    iex> Pharkdown.Parser.tokenize("# Un grand titre\\nUn simple paragraphe.")
    [
      {:title, [index: 1, content: "Un grand titre", level: 1]},
      {:paragraph, [index: 2, content: "Un simple paragraphe."]},
    ]

    - Environnement -

    iex> Pharkdown.Parser.tokenize("document/\\nPremière ligne\\nDeuxième ligne\\n/document\\nAutre paragraphe")
    [
      {:environment, [index: 1, content: "Première ligne\\nDeuxième ligne", type: :document]},
      {:paragraph, [index: 2, content: "Autre paragraphe"]}
    ]

    - Liste -

    iex> Pharkdown.Parser.tokenize("* Premier item\\n* Deuxième item\\n* Troisième item")
    [
      {
        :list, 
        [
          index: 1, type: :regular, first: nil, 
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
          index: 1, type: :ordered, first: 5, 
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
      {:paragraph, [index: 4, content: "Tout premier paragraphe"]},
      {:title, [index: 1, content: "Titre", level: 1]},
      {
        :list,  [
          index: 3, type: :regular, first: nil, 
          content: [
            [content: "item 1", level: 1], 
            [content: "item 2", level: 1]
          ]
        ]
      },
      {:title, [index: 2, content: "Autre titre", level: 2]},
      {:paragraph, [index: 5, content: "Paragraphe"]}
    ]

    - Ordre différent -

    iex> Pharkdown.Parser.tokenize("document/\\nLa ligne\\n/document\\n## Le sous-titre")
    [
      {:environment, [index: 2, content: "La ligne", type: :document]},
      {:title, [index: 1, content: "Le sous-titre", level: 2]}
    ]

   
  NOTES
  -----

    N000
      Bien comprendre que les tokens sont ramassés dans le désordre
      dans le texte. On ramasse d'abord les titres, donc ils sont
      placés en premier dans collector.tokens (pas le final, mais le
      collector.tokens intermédiaire) même s'ils sont après d'autres
      choses. C'est la raison pour laquelle on place toutes les 
      marques de token TOKEN_xx_TOKEN dans le texte, pour pouvoir 
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
  @regex_titres ~r/^(\#{1,7}) (.+)$/m
  @regex_blockcode ~r/(~~~|```)([a-z]+\n)?(.+)\n\1/ms
  @regex_known_environments ~r/^(#{Enum.join(@known_environments, "|")})\/\n(.+)\n\/\1$/ms

  def tokenize(string, options \\ []) do
    collector = %{texte: string, tokens: [], index: 0, options: options}
    
    # IO.inspect(string, label: "\nSTRING AU DÉPART")
    
    # note : toutes ces fonctions retourne +collector+
    collector
    |> scan_titres_in()
    |> scan_blockcode_in()
    |> scan_for_known_environments()
    # Il faut scanner les listes après les environnements car des 
    # environnements peuvent se trouver dans les listes (cf. N001)
    |> scan_for_list_in()
    |> scan_for_rest() # tout ce qui reste est considéré comme des paragraphes
    |> reorder_tokens() # on met les tokens dans l'ordre (cf. N000)
    |> (fn coll -> coll.tokens end).()
    # collector.tokens contient maintenant la liste ordonnée de tous
    # les tokens qui constituent le texte. On n'a plus besoin du reste.
  end

  # Méthode générique pour ajouter un token dans le collecteur
  #
  # Concrètement, cette méthode : 
  #   1) définit le nouvelle index pour la marque du token
  #   2) remplace le texte trouvé dans le texte par la marque du token
  #   3) ajoute le token AST-like à la liste des tokens
  #
  #   Note : la fonction ajoute toujours l'index courant au +data+
  #          transmises.
  #
  # @param collector  Map  Le collecteur général
  # @param type       Atom Le type de token, par exemple :title ou :paragraph
  # @param data       List les données propres au token (par exemple
  #                   le :level pour un titre)
  # @param found      Le texte trouvé dans le texte actuel.
  #
  defp add_to_collector(collector, type, data, found) do
    new_index = collector.index + 1
    data = Keyword.put(data, :index, new_index)
    # remp  = "TOKEN_#{new_index}_TOKEN\n" # ATTENTION : ajouter un retour
                # chariot ici fait planter l'analyse d'un environnement à
                # l'intérieur d'une liste.
    remp  = "TOKEN_#{new_index}_TOKEN"
    new_texte = 
      case collector.texte do
      x when is_binary(x) -> 
        String.replace(collector.texte, found, remp)
      x when is_list(x) ->
        collector.texte ++ [remp]
      end
    # |> IO.inspect(label: "collector.texte après #{inspect(type)}")

    Map.merge(collector, %{
      index:  new_index, 
      texte:  new_texte,
      tokens: collector.tokens ++ [{type, data}]
    })
  end


  defp scan_titres_in(collector) do
    case Regex.scan(@regex_titres, collector.texte) do
    nil -> collector
    res -> Enum.reduce(res, collector, fn groupes, collector ->
        [tout, level, contenu] = groupes

        # Données pour le token
        data = [
          index:    collector.index + 1,
          content:  String.trim(contenu), 
          level:    String.length(level)
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
            content: String.trim(contenu), 
            langage: String.trim(langage)
          ]
          add_to_collector(collector, :blockcode, data, tout)
        end)
      end
  end

  # Méthode qui va parser et tokeniser les listes qui se présentent
  # sous la forme "* item" ou "- item" ou "1- item"
  # L'expression recherche :
  #   - un string commençant par "* ", "- " ou "1- "
  #   - et allant jusqu'à une ligne ne contenant pas "\n*" ou "\n-"
  #     ou la fin
  @regex_list ~r/
  ^ # un début de ligne
  ([0-9]+)?     # qui commence peut être par un chiffre pour une
                # liste numérotée
  (             # Pour avoir tout ce qui faut pour trouver ensuite
                # les items indépendants
    (?:[\*\-]+ .+) # suivi par une ou plusieurs astérisques ou tirets
    (?:
      \n(?:[\*\-]+ |TOKEN_)(?:.+)
    )*            # Autant de fois qu on peut en trouver
  )             # Tous les items -- sans numéro
  $             # La fin de ligne
  /xm
  # (?!           # qui ne doit pas contenir ensuite
  #   \n          # un retour chariot suivi de
  #   (           # soit…
  #   ([\*\-]+ )  # 1 ou plusieurs astérisques ou tirets suivi par 
  #               # espace
  #   |           # ou
  #   TOKEN_      # une marque d'environnement
  #   )|\z)/msx
  @reg_list_item ~r/^(?:([\*\-]+) (.+)|TOKEN_([0-9]+)_TOKEN)$/m
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
  defp scan_for_known_environments(collector) do
    collector.tokens
    Regex.scan(@regex_known_environments, collector.texte)
    |> Enum.reduce(collector, &treat_known_environment/2)
  end

  defp treat_known_environment(found, collector) do
    [tout, env_name, content] = found
    env_name = @environment_substitution[env_name] || env_name
    data = [
      content: content, 
      type: String.to_atom(env_name)
    ]
    add_to_collector(collector, :environment, data, tout)
    # |> IO.inspect(label: "\nCollector après ajout de #{tout}")
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
    |> (fn collector -> 
      %{collector | texte: Enum.join(collector.texte, "\n")}
    end).()
  end


  def reorder_tokens(collector) do
    
    ini_tokens  = collector.tokens
    # |> IO.inspect(label: "\nTous les tokens avant ré-ordonnancement")
    collector   = %{collector | tokens: []}

    # IO.inspect(collector.texte, label: "\nCollector.Texte avant ré-ordonnancemnt")

    Regex.scan(@regex_balise_token_multi, collector.texte)
    |> Enum.reduce(collector, fn found, coll ->
      [_tout, index] = found
      index = String.to_integer(index) - 1
      # IO.inspect(index, label: "INDEX")
      %{ coll | tokens: coll.tokens ++ [Enum.at(ini_tokens, index)] }
    end)
    # |> IO.inspect(label: "\nCOLLECTOR avec TOKENS RÉ-AGENCÉS")
  end

end #/module Pharkdown.Parser