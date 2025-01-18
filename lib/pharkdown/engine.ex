defmodule Pharkdown.Engine do
  @moduledoc """
  Engin de rendu pour le format Pharkdown (.phad).
  """

  @behaviour Phoenix.Template.Engine

  # Options par défaut
  @default_options [
    smarties: true, 
    correct:  true
  ]

  alias Pharkdown.{Loader, Parser, Formatter}

  @doc """
  Fonction principale, requise, pour produire le code AST permettant
  de rendre la page.
  """
  @impl true
  def compile(path, options \\ []) do

    content = File.read!(path)
    options = compile_options(path, options)
    |> IO.inspect(label: titre_exerg("OPTIONS"))

    quote do
      unquote(compile_string(content, options))
    end
  end

  @doc """
  Transforme le texte +string+, formaté en Pharkdown, en un texte 
  HTML conforme.
  """
  def compile_string(string, options \\ nil) do
    options = is_nil(options) && compile_options(nil, []) || options
    string
    |> Loader.load_external_contents(options)
    # |> IO.inspect(label:  titre_exerg("After Loader.load_external_contents/2"))
    |> Parser.parse(options)
    # |> IO.inspect(label: titre_exerg("After Parser.parse/2"))
    |> Formatter.formate(options)
    # |> IO.inspect(label: titre_exerg("After Formatter.formate/2"))
    |> Formatter.very_last_correction(options)
    # |> IO.inspect(label: titre_exerg("After Formatter.very_last_correction/2"))
  end

  defp titre_exerg(str), do: IO.ANSI.green() <> "\n#{str}\n" <> IO.ANSI.reset()

  # Crée le fichier +html_path+ à partir du fichier +phad_path+
  def compile_file(phad_path, html_path) do
    File.write!(html_path, compile(phad_path))
  end

  def compile_options(nil, options) do
    # Options du programmeur
    app_options = Keyword.merge(
      @default_options, 
      Application.get_env(:pharkdown, :options, [])
    )
    # Compilation de toutes les options
    options ++ app_options
  end

  def compile_options(path, options) do
    # Options générales
    options = compile_options(nil, options)
    # Pour informations (débuggage et erreur)
    file_infos = [ path: path, fname: Path.basename(path) ]
    # Compilation de toutes les options
    options ++ file_infos
  end


end #/module Pharkdown.Engine