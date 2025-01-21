defmodule Pharkdown.Params do
  @moduledoc """
  Traitement des paramètres qu'on peut trouver à différents endroits :
  * en début de ligne : <tag>#<id>.<class>: Mon paragraphe stylé
  * dans un lien href ou ref : [Titre][x|#<id>.<class>] ou [Titire][x|att=val]
  """

  defstruct [
    tag:    nil,  # Tout premier élément, si défini
    id:     nil,  # Pour un identifiant
    class:  [],   # une liste de classes CSS
    attrs:  [],   # une liste d'attributs (attr=valeur => [attr, value] => attr="value")
    props:  []    # liste de propriétés CSS (prop:value => [prop, value] => "prop:value;")
  ]

  @doc """
  ## Description
  
  Parse le string +params+ et retourne une structure 
  %Pharkdown.Params{} définissant les éléments trouvés.

  ## Examples
  
    iex> Params.parse("")
    nil

    iex> Params.parse(nil)
    nil

    iex> Params.parse("color:#FFFFFF")
    %Params{tag: nil, props: [["color", "#FFFFFF"]]}

    iex> Params.parse(".classcss")
    %Params{tag: nil, props: [], attrs: [], class: ["classcss"]}

    iex> Params.parse("#identifiant")
    %Params{tag: nil, id: "identifiant", class: [], props: [], attrs: []}

    iex> Params.parse("attri=#valeuri")
    %Params{tag: nil, id: nil, attrs: [["attri", "#valeuri"]], props: []}

    iex> Params.parse("propa:valpa,tagi#ident.classcss.autrecss,attri=vali,propi:valpi")
    %Params{
      tag: "tagi", 
      id: "ident", 
      class: ["classcss", "autrecss"], 
      attrs: [["attri","vali"]], 
      props: [ ["propa", "valpa"], ["propi", "valpi"]]
    }


  """
  @reg_params ~r/([#.,])/; @reg_options [{:trim, false}, {:include_captures, true}]
  def parse(nil), do: nil
  def parse(""), do: nil
  def parse(params) do
    params
    |> String.split(",")
    |> Enum.reduce(%__MODULE__{}, fn x, iparams -> 
      cond do
      x =~ ~r/=/ ->
        # Pour une valeur d'attribut
        %{ iparams | attrs: iparams.attrs ++ [String.split(x, "=") |> Enum.map(fn x -> String.trim(x) end)] }
      x =~ ~r/:/ ->
        # Pour une valeur de propriété CSS
        %{ iparams | props: iparams.props ++ [String.split(x, ":") |> Enum.map(fn x -> String.trim(x) end)] }
      true ->
        # Dans tous les autres cas
        founds = Regex.split(@reg_params, x, @reg_options)
        {tag, founds} = List.pop_at(founds, 0)
        iparams = %{ iparams | tag: tag|>SafeString.nil_if_empty()}
        Enum.chunk_every(founds, 2)
        |> Enum.reduce(iparams, fn paire, iparams ->
          [car, value] = paire
          case car do
          "#" -> %{ iparams | id: value }
          "." -> %{ iparams | class: iparams.class ++ [value] }
          end
        end)
      end #/cond 
    end)
  end


  # --- Fonctions de formatage ---

  @doc """
  Formate l'attribut id d'une balise

  ## Examples

    iex> Params.id_as_attr(nil)
    ""
    iex> Params.id_as_attr(%Params{id: nil})
    ""

    iex> Params.id_as_attr(%Params{id: "identity"})
    ~s( id="identity")
  """
  def id_as_attr(nil), do: ""
  def id_as_attr(%__MODULE__{id: nil}), do: ""
  def id_as_attr(%__MODULE__{id: id}) do
    ~s( id="#{id}")
  end

  @doc """
  Formate les attributs fournis

  ## Examples

    iex> Params.attrs_as_attr(nil)
    ""

    iex> Params.attrs_as_attr(%Params{attrs: []})
    ""

    iex> Params.attrs_as_attr(%Params{attrs: [ ["data-id", "identity"], ["deleted", "true"] ]})
    ~s( data-id="identity" deleted="true")

  """
  def attrs_as_attr(nil), do: ""
  def attrs_as_attr(%__MODULE__{attrs: []}), do: ""
  def attrs_as_attr(%__MODULE__{attrs: attrs}) do
    attrs
    |> Enum.map(fn [attr, value] ->
      ~s( #{attr}="#{value}")
    end)
    |> Enum.join("")
  end

  @doc """
  Formate l'attribut class dans la balise

  ## Examples

    iex> Params.class_as_attr(nil)
    ""

    iex> Params.class_as_attr(%Params{class: []})
    ""
    
    iex> Params.class_as_attr(%Params{class: ["css1", "css2"]})
    ~s( class="css1 css2")

  """
  def class_as_attr(nil), do: ""
  def class_as_attr(%__MODULE__{class: []}), do: ""
  def class_as_attr(%__MODULE__{class: classes}) do
    ~s( class="#{Enum.join(classes, " ")}")
  end

  @doc """
  Formate les propriétés CSS dans une balise

  ## Examples

    iex> Params.props_as_style(nil)
    ""
    
    iex> Params.props_as_style(%Params{props: []})
    ""

    iex> Params.props_as_style(%Params{props: [ ["height", "12px"], ["color", "#CCCCCC"] ]})
    ~s( style="height:12px;color:#CCCCCC;")

  """
  def props_as_style(nil), do: ""
  def props_as_style(%__MODULE__{props: []}), do: ""
  def props_as_style(%__MODULE__{props: props}) do
    props
    |> Enum.map(fn [prop, value] -> 
      "#{prop}:#{value};"
    end)
    |> Enum.join("")
    |> (fn style -> ~s( style="#{style}") end).()
  end
end