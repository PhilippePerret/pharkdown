defmodule TransformerTests do
  use ExUnit.Case

  alias Transformer, as: T
  
  doctest Transformer

  describe "Méthode h" do

    test ":than_less avec balise échappée" do
      code = "\\<balise>"
      actual = code |> T.h(:less_than)
      expect = "<balise>"
      assert actual == expect

      code = "Pour \\<balise>"
      actual = code |> T.h(:less_than)
      expect = "Pour <balise>"
      assert actual == expect

      code = "<balise avec> \\<balise sans>"
      actual = code |> T.h(:less_than)
      expect = "&lt;balise avec> <balise sans>"
      assert actual == expect
    end
  end #/methode h


end
