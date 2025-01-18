defmodule Transformer do
  @moduledoc """
  Module permettant des transformations diverses avec des codes très
  courts (par exemple `T.h()' ).

  Utiliser    alias Transformer, as: T
  
  … pour pouvoir utiliser des choses très courtes comme :
    T.h "mon string à transformer"

  """


  @doc """
  Transformations vers HTML

  # Examples

    //Espaces insécables -> &nbsp;
    iex> "bonjour !" |> T.h()
    "bonjour&nbsp;!"

    // Avec l'option :less_than
    iex> "une <balise>" |> T.h(:less_than)
    "une &lt;balise>"

  """
  def h(string, :less_than) when is_binary(string) do
    string |> String.replace("<", "&lt;")
  end

  def h(string) when is_binary(string) do
    string |> String.replace(~r/ /, "&nbsp;")
  end



end
