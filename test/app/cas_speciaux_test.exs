defmodule PharkdownCasSpeciauxTests do
  @moduledoc """
  Ce module permet de tester des cas spéciaux qui entrainent des 
  traitements particuliers.
  """
  use ExUnit.Case

  alias Pharkdown.Engine

    # Cette disposition :
    #   ««« "bonjour" ! »»» 
    # entraine une double correction des anti-wrappers. Car le texte
    # va d'abord être corrigé par : 
    #   ««« « bonjour » ! »»»
    # et ensuite les anit-wrappers vont être mis :
    #   1) pour les guillemets
    #   2) pour le point d'exclamation
    # ce qui va entrainer une double mise des <nowrap>
    # Il faut donc veiller à ce que ces transformations soient bien
    # respectées :
    #   "bonjour" ! -> <nowrap>« bonjour » !</nowrap>
    #   "bonjour tout le monde" ! -> « bonjour tout le <nowrap>monde » !</nowrap>


  describe "Anti-wrappers avec guillemets + tirets + ponctuation double" do
    test "simple mot entre guillemets" do
      code = "— \"bonjour\" — !"
      actual = Engine.compile_string(code)
      expect = "<div class=\"p\"><nowrap>— « bonjour » — !</nowrap>" |> String.replace(~r/ /, '&nbsp;')
      assert actual == expect
    end
    test "plusieurs mots entre guillemets" do
      code = "— \"bonjour tout le monde\" — !"
      actual = Engine.compile_string(code)
      expect = "<div class=\"p\">–&nbsp;«&nbsp;bonjour tout le <nowrap>monde&nbsp;»&nbsp;—&nbsp;!</nowrap>"
      assert actual == expect
    end

  end
end
