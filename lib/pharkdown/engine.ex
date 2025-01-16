defmodule Pharkdown.Engine do
  @moduledoc """
  Engin de rendu pour le format Pharkdown (.phad).
  """

  @behaviour Phoenix.Template.Engine

  alias Pharkdown.{Loader, Parser, Formatter}

  @doc """
  Fonction principale, requise, pour produire le code AST permettant
  de rendre la page.
  """
  @impl true
  def compile(path, options) do

    content = File.read!(path)

    # Pour informations (débuggage et erreur)
    options = [ {:path, path}, {:fname, Path.basename(path)} | options]

    quote do
      #                                                                        cf. N001
      # unquote(content |> Parser.parse(options) |> Formatter.formate(options) |> Formatter.formate(options))
      unquote(compile_string(content, options))
    end
  end

  @doc """
  Transforme le texte +string+, formaté en Pharkdown, en un texte 
  HTML conforme.
  """
  def compile_string(string, options \\ []) do
    string
    |> Loader.load_external_contents(options)
    # |> IO.inspect(label:  titre_ex("After Loader.load_external_contents/2"))
    |> Parser.parse(options)
    |> IO.inspect(label: titre_ex("After Parser.parse/2"))
    |> Formatter.formate(options)
    |> IO.inspect(label: titre_ex("After Formatter.formate/2"))
    |> Formatter.very_last_correction(options)
    # |> IO.inspect(label: titre_ex("After Formatter.very_last_correction/2"))
  end

  defp titre_ex(str), do: IO.ANSI.green() <> "\n#{str}\n" <> IO.ANSI.reset()

  # Crée le fichier +html_path+ à partir du fichier +phad_path+
  def compile_file(phad_path, html_path, phad_name) do
    File.write!(html_path, compile(phad_path, [{:name, phad_name}]))
  end
end #/module Pharkdown.Engine