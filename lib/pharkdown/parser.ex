defmodule Pharkdown.Parser do

  alias Pharkdown.Formater

  def parse(string, options) do
    string
    |> explode_code(options)
  end

  def explode_code(string, options) when is_binary(string) do
    string
    |> String.replace("\r", "")
    |> tokenize(options)
  end


  @doc """
  Méthode qui prend un texte en entrée (qui peut être long) et le
  découpe en blocs identifié par des atoms.

  ## Examples

    iex> Pharkdown.Parser.tokenize("Une simple phrase")
    {:paragraph, content: "Une simple phrase"}

    iex> Pharkdown.Parser.tokenize("# Un titre simple")
    {:title, content: "Un titre simple", level: 1}
    
  """
  def tokenize(string, options \\ []) when is_binary(string) do
    string
    |> String.split("\n") # pour le moment
  end
end #/module Pharkdown.Parser