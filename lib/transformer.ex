defmodule Transformer do
  @moduledoc """
  Module permettant des transformations diverses, pour le moment 
  surtout réservées aux tests.

  Utiliser    alias Transformer, as: T
  
  … pour pouvoir utiliser des choses très courtes comme :
    T.h "mon string à transformer"

  """

  @doc """
  Transformations vers HTML

  Espaces insécables -> &nbsp;
  """
  def h(string) when is_binary(string) do
    string
    |> String.replace(~r/ /, "&nbsp;")
  end

end