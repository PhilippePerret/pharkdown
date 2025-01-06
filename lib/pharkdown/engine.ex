defmodule Pharkdown.Engine do
  @moduledoc """
  Engin de rendu pour le format Pharkdown (.phad).
  """

  @behaviour Phoenix.Template.Engine

  alias Pharkdown.Parser
  alias Pharkdown.Formater

  @impl true
  def compile(path, options) do

    content = File.read!(path)

    quote do
      unquote(Parser.parse(content, options))
    end
  end

end #/module Pharkdown.Engine