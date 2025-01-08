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

end #/module Pharkdown.Engine