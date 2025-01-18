defmodule StringTo do

  @reg_empty_list ~r/^\[[  \t]*\]$/
  @reg_inner_list ~r/^\[(.*)\]$/

  @reg_atom ~r/^\:[a-z_]+$/
  @reg_instring ~r/^"(.*)"$/
  @reg_integer ~r/^[0-9]+$/
  @reg_float ~r/^[0-9.]+$/
  @reg_const ~r/(true|false|nil)/
  @reg_pourcent_int ~r/^([0-9]+)\%$/
  @reg_pourcent_float ~r/^([0-9.]+)\%$/
  @reg_size_int ~r/^(?<value>[0-9]+)(?<unity>cm|px|pt|cm|mm|po|inc)$/
  @reg_size_float ~r/^(?<value>[0-9.]+)(?<unity>cm|px|pt|cm|mm|po|inc)$/
  @reg_range ~r/^[0-9]+\.\.[0-9]+$/

  @doc """
  Function qui reçoit un string quelconque et retourne la
  valeur correspondante en fonction de son contenu.

  Transformations possibles :

  "string"      => "string" (pas de transformation)
  "200"         => 200
  "1..100"      => 1..100
  "20.0"        => 20.0
  "true"        => true
  "false"       => false
  "nil"         => nil
  "[<valeurs>]" => [<valeurs>] si possible
  "50%"         => %{type: :pourcent, value: 50}
  "50.2cm"      => %{type: :size, value: 50.2, unity: "cm"}
    Ou autres unités : "po", "inc", "mm", "px"

  """
  def value(x) when is_binary(x) do
    cond do
    x =~ @reg_inner_list -> list(x) # une liste reconnaissable
    x =~ @reg_atom      -> elem(Code.eval_string(x),0)  # :atom
    x =~ @reg_instring  -> elem(Code.eval_string(x),0)  # String
    x =~ @reg_range     -> elem(Code.eval_string(x),0)  # Range
    x =~ @reg_integer   -> String.to_integer(x)         # Integer
    x =~ @reg_float     -> String.to_float(x)           # Float
    x =~ @reg_const     -> elem(Code.eval_string(x),0)  # true, false,...
    xr = Regex.run(@reg_pourcent_int, x) -> 
      xr = xr |> Enum.at(1)
      %{type: :pourcent, value: String.to_integer(xr), raw_value: x}
    xr = Regex.run(@reg_pourcent_float, x) -> 
      xr = xr |> Enum.at(1)
      %{type: :pourcent, value: String.to_float(xr), raw_value: x}
    xr = Regex.named_captures(@reg_size_int, x) ->
      %{type: :size, value: String.to_integer(xr["value"]), unity: xr["unity"], raw_value: x}
    xr = Regex.named_captures(@reg_size_float, x) ->
      %{type: :size, value: String.to_float(xr["value"]), unity: xr["unity"], raw_value: x}
    true -> x # comme string ou autre
    end
  end
  def value(x), do: x


  @doc """
  Function qui reçoit un string est retourne une liste

  Le string peut être sous la forme :

    "" ou "  "              => []
    "Un, deux, trois"       => ["Un", "deux", "trois"]
    "Un, 12, true"          => ["Un", 12, true]
    "Un, \"12\", \"true\""  => ["Un", "12", "true"]
    "Un, :atom, "           => ["Un", :atom, ""]
    "[Un, deux, trois]"     => ["Un", "deux", "trois"]
    "[Un, 1.2, false]"      => ["Un", 1.2, false]
    "Avec\, oui, non"       => ["Avec, oui", "non"]
    "[Avec\, oui, non]"     => ["Avec, oui", "non"]
    "[\"Un\", \"deux\"]"    => ["Un", "deux"]

  """
  def list(str) when is_binary(str) do
    trimed_str = String.trim(str)
    if trimed_str == "" || trimed_str =~ @reg_empty_list do
      []
    else
      trimed_str
      |> String.replace(@reg_inner_list, "\\1")
      |> String.replace("\\,", "__VIRGU__")
      |> String.split(",")
      # - Une liste à partir d'ici -
      |> Enum.map(fn x -> 
          x
          |> String.replace("__VIRGU__", ",")
          |> String.trim()
          |> StringTo.value()
        end)
    end
  end
  def list(foo) do
    IO.inspect(foo, label: "\nN'est pas un string envoyé à StringTo.list")
    foo
  end

  # Fait les transformation d'usage dans les strings.
  # à savoir :
  #   les backstick par deux sont remplacés par des <code>
  #   1^er  en exposant
  #   *italique*
  #   **gras**
  #   __souligné__
  #   --barré--
  #   --barré//remplacé--
  #

  # Ne pas oublier de mettre ici tous les "candidats", c'est-à-dire
  # tous les textes qui peuvent déclencher la correction.
  @reg_candidats_html ~r/[\`\*_\-\^\\\"\'\:\;\!\?]/

  # Expression régulière pour capturer les codes entre backsticks.
  # Note : on en profite pour remplacer les '<' par des '&lt;'.
  @reg_backsticks ~r/\`(.+)\`/U; @remp_backsticks "<code>\\1</code>"
  @reg_bold_ital ~r/\*\*\*(.+)\*\*\*/U; @remp_bold_ital "<b><em>\\1</em></b>"
  @reg_bold ~r/\*\*(.+)\*\*/U; @remp_bold "<b>\\1</b>"
  @reg_ital ~r/\*([^ ].+)\*/U; @remp_ital "<em>\\1</em>"
  @reg_underscore ~r/__(.+)__/U; @remp_underscore "<u>\\1</u>"
  @reg_substitute ~r/\-\-(.+)\/\/(.+)\-\-/U; @remp_substitute "<del>\\1</del> <ins>\\2</ins>"
  @reg_strike ~r/\-\-(.+)\-\-/U; @remp_strike "<del>\\1</del>"
  @reg_exposant ~r/\^(.+)(\W|$)/U; @remp_exposant "<sup>\\1</sup>\\2"
  @reg_guillemets ~r/"(.+)"/U; @remp_guillemets "« \\1 »"
  @reg_return ~r/( +)?\\n( +)?/; @remp_return "<br />"
  @reg_line ~r/(^|\r?\n)\-\-\-(\r?\n|$)/; @remp_line "\\1<hr />\\2"
  
  # Expression régulière pour capter les textes du style :
  #   ««« un mot ? »»»
  # et les transformer en :
  #   ««« un <nowrap>mot ?</nowrap>
  # Note
  # Penser qu'on peut avoir des styles, par exemple <em>un mot</em> 
  # et qu'on ne peut donc pas utiliser le \b
  #
  @reg_ponct_nowrap ~r/ ([^ ]+)([  ])([!?:;])/U ; @temp_ponct_nowrap " <nowrap>\\1\\2\\3</nowrap>"
  # Si le <nowrap> ne se révèle pas efficace, utiliser plutôt :
  # @reg_ponct_nowrap ~r/ ([^ ]+)([  ])([!?:;])/U ; @temp_ponct_nowrap " <span class=\"nowrap\">\\1\\2\\3</span>"

  def html(str, _options \\ %{}) do
    # Il faut que le string contienne un "candidat" pour que
    # la correction soit amorcée.
    if Regex.match?(@reg_candidats_html, str) do

      str = str
      |> String.replace(@reg_return, @remp_return)
      
      {str, protecteds} = get_all_protected_cars(str)
      
      str = str
      |> String.replace("'", "’")
      |> String.replace(@reg_guillemets, @remp_guillemets)
      |> String.replace(@reg_line, @remp_line)
      |> (&Regex.replace(@reg_backsticks, &1, fn _tout, code -> 
          "<code>" <> String.replace(code, "<", "&lt;") <> "</code>"
        end)).()
      |> String.replace(@reg_bold_ital, @remp_bold_ital)
      |> String.replace(@reg_bold, @remp_bold)
      |> String.replace(@reg_ital, @remp_ital)
      |> String.replace(@reg_underscore, @remp_underscore)
      |> String.replace(@reg_substitute, @remp_substitute)
      |> String.replace(@reg_strike, @remp_strike)
      |> String.replace(@reg_exposant, @remp_exposant)
      |> String.replace(@reg_ponct_nowrap, @temp_ponct_nowrap)

      if Enum.empty?(protecteds) do
        str
      else
        reput_all_protected_cars(str, protecteds)
      end
    else
      str
    end
  end

  defp get_all_protected_cars(str) do
    if not String.contains?(str, "\\") do
      # IO.puts "pas d'échappements dans #{inspect(str)}"
      {str, []}
    else
      # IO.puts "Il y a des échappements"
      collector =
        str
        |> String.split("\\") # => liste de tous les segments
        |> Enum.reduce(%{index: 0, remp: [], segments: []}, fn seg, coll ->
          case seg do
          "" ->
            Map.merge(coll, %{segments: coll.segments ++ [""]})
          _ ->
            protected = String.at(seg, 0)
            new_remp = "PPROTECTEDCARR#{coll.index}"
            new_segment = String.replace_leading(seg, protected, new_remp)
            Map.merge(coll, %{
              remp:     coll.remp ++ [protected],
              segments: coll.segments ++ [new_segment],
              index:    coll.index + 1
            })
          end
        end)

      {
        Enum.join(collector.segments, ""),
        collector.remp
      }
    end
  end

  defp reput_all_protected_cars(str, protecteds) do
    protecteds
    |> Enum.with_index(0)
    |> Enum.reduce(str, fn {protected, index}, str -> 
        String.replace(str, "PPROTECTEDCARR#{index}", protected)
      end)
  end

end