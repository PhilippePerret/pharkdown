defmodule Pharkdown.Engine do
  @moduledoc """
  Engin de rendu pour le format Pharkdown (.phad).
  """

  @behaviour Phoenix.Template.Engine

  alias Pharkdown.Parser
  alias Pharkdown.Formater
  alias Pharkdown.Loader

  @impl true
  def compile(path, options) do

    content = 
      File.read!(path)
      |> Loader.load_external_contents(options)

    quote do
      unquote(content |> Parser.parse(options) |> Formater.formate(options))
    end
  end

  # Crée le fichier +html_path+ à partir du fichier +phad_path+
  def compile_file(phad_path, html_path, phad_name) do
    File.write!(html_path, compile(phad_path, []))
  end
end #/module Pharkdown.Engine