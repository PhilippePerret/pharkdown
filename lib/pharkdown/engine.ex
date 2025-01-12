defmodule Pharkdown.Engine do
  @moduledoc """
  Engin de rendu pour le format Pharkdown (.phad).
  """

  @behaviour Phoenix.Template.Engine

  alias Pharkdown.Parser
  alias Pharkdown.Formatter
  alias Pharkdown.Loader

  @doc """

  NOTES
    N001
      La première Formater.formate/2 reçoit une liste (de tokens) la 
      deuxième reçoit le string produit par la première.
  """
  @impl true
  def compile(path, options) do

    content = 
      File.read!(path)
      |> Loader.load_external_contents(options)

    quote do
      #                                                                        cf. N001
      unquote(content |> Parser.parse(options) |> Formatter.formate(options) |> Formatter.formate(options))
    end
  end

  # Crée le fichier +html_path+ à partir du fichier +phad_path+
  def compile_file(phad_path, html_path, phad_name) do
    File.write!(html_path, compile(phad_path, [{:name, phad_name}]))
  end
end #/module Pharkdown.Engine