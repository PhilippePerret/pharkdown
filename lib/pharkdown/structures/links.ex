defmodule Pharkdown.Link do
  defstruct [
    href: nil, # url + query-string + anchor
    url: nil,
    query_string: nil,
    anchor: nil,
    title: nil,
    vroute: false, # route vérifiée
    attributes: nil
  ]

  @doc """
  ## Traite tous les liens dans le texte +string+
  """
  @regex_links ~r/\[(?<title>.+)\]\((?<href>.+)(?:\|(?<params>.+))?\)/U
  def treate_links_in(string) when is_binary(string) do
    Regex.replace(@regex_links, string, fn _, title, href, params ->
      treate(title, href, params)
    end)
  end

  @doc """
  ## Traitement d'un lien [titre](href)

  """
  def treate(title, href, params) do
    Pharkdown.Link.parse(title, href, params)
    |> Pharkdown.Link.formate()
  end

  @doc """
  Fonction qui reçoit le résultat trouvé du scan du texte avec l'ex-
  pression régulière @regex_links (cf. formatter.ex) et retourne une
  structure %Pharkdown.Link{} prête à l'emploi.

  ## Examples

    iex> Link.parse("Titre", "mon/url", nil)
    %Link{title: "Titre", href: "mon/url", url: "mon/url", anchor: nil, query_string: nil, attributes: nil, vroute: false}

    iex> Link.parse("Titre", "mon/url#ancre", nil)
    %Link{title: "Titre", href: "mon/url#ancre", url: "mon/url", anchor: "ancre", query_string: nil, attributes: nil, vroute: false}

    iex> Link.parse("Titre", "mon/url?pararm=valeur", nil)
    %Link{title: "Titre", href: "mon/url?pararm=valeur", url: "mon/url", anchor: nil, query_string: "pararm=valeur", attributes: nil, vroute: false}

    iex> Link.parse("Titre", "mon/url?pararm=valeur#ancre", nil)
    %Link{title: "Titre", href: "mon/url?pararm=valeur#ancre", url: "mon/url", anchor: "ancre", query_string: "pararm=valeur", attributes: nil, vroute: false}

  """
  @regex_href ~r/^(?<u>.+)(\?(?<qs>.+))?(?:\#(?<a>.+))?$/U
  @regex_verified_route ~r/^\{(.+)\}$/
  def parse(title, href, params) when is_binary(title) and is_binary(href) do
    # On découpe +href+ pour obtenir les éventuelles ancres et
    # query-strings
    href = String.trim(href)
    is_verified_route = Regex.match?(@regex_verified_route, href)
    href =
      if is_verified_route do
        String.slice(href, 1, String.length(href) - 2)
      else
        href
      end
    %{
      "u" => url, "qs" => query_string, "a" => anchor
    } = Regex.named_captures(@regex_href, href)
    %Pharkdown.Link{
      title: title,
      href: href, 
      url: url,
      vroute: is_verified_route,
      query_string: SafeString.nil_if_empty(query_string),
      anchor: SafeString.nil_if_empty(anchor),
      attributes: parse_params(params)
    }
  end

  def parse_params(nil), do: nil
  def parse_params(""), do: nil
  def parse_params(params) do
    params
    |> String.split(",") 
    |> Enum.map(fn i -> String.trim(i) end)
    |> Enum.map(fn i -> String.split(i, "=") end)
    |> Enum.map(fn [attr, val] -> ~s(#{attr}="#{val}") end)
    |> (fn liste -> " " <> Enum.join(liste, " ") end).()
  end

  @doc """
  Reçoit une structure t() et retourne un <a> à coller dans le texte.

  ## Examples

    iex> Link.parse("Titre", "mon/lien",  nil) |> Link.formate()
    ~s(<a href="mon/lien">Titre</a>)

    iex> Link.parse("Titre", "mon/lien",  "style=color:red;") |> Link.formate()
    ~s(<a href="mon/lien" style="color:red;">Titre</a>)
    
    iex> Link.parse("Titre", "mon/lien?param=value",  nil) |> Link.formate()
    ~s(<a href="mon/lien?param=value">Titre</a>)

    iex> Link.parse("Titre", "{mon/lien}", nil) |> Link.formate()
    ~s(<a href={~p"/mon/lien"}>Titre</a>)

    iex> Link.parse("Titre", "{/mon/lien}", nil) |> Link.formate()
    ~s(<a href={~p"/mon/lien"}>Titre</a>)

    iex> Link.parse("Titre", "mon/lien#ancre", nil) |> Link.formate()
    ~s(<a href="mon/lien#ancre">Titre</a>)

    iex> Link.parse("Titre", "{mon/lien#ancre}", nil) |> Link.formate()
    ~s(<a href={~p"/mon/lien" <> "#ancre"}>Titre</a>)

    iex> Link.parse("Titre", "{mon/lien?param=value#ancre}", nil) |> Link.formate()
    ~s(<a href={~p"/mon/lien" <> "?param=value" <> "#ancre"}>Titre</a>)

    iex> Link.parse("Titre", "{mon/lien?param=value}", nil) |> Link.formate()
    ~s(<a href={~p"/mon/lien" <> "?param=value"}>Titre</a>)

  """
  def formate(%__MODULE__{} = plink) do
    target = target_for(plink.href)
    href   = href_for(plink)
    "<a href=#{href}#{plink.attributes}#{target}>#{plink.title}</a>"
  end

  defp target_for(href) do
    String.starts_with?(href, "http") && " target=\"_blank\"" || ""
  end

  defp href_for(%__MODULE__{} = plink) do
    href = plink.url
    mark_anchor = plink.anchor && "##{plink.anchor}" || ""
    mark_qstring = plink.query_string && "?#{plink.query_string}" || ""
    case plink.vroute do
    false -> 
      ~s("#{href}#{mark_qstring}#{mark_anchor}")
    true ->
      route = plink.url
      "{" <> (case String.starts_with?(route, "~p") do
      true  -> 
        String.replace(route, ~r/^~p(.+)$/, ~s(~p"\\1"))
      false -> 
        route = String.starts_with?(route, "/") && route || "/#{route}"
        ~s(~p"#{route}")
      end) <> (if plink.query_string do
        ~s( <> "?#{plink.query_string}")
      else ""
      end) <> (if plink.anchor do
        ~s( <> "##{plink.anchor}")
      else ""
      end) <> "}"
    end
  end

end #/module Pharkdown.Link