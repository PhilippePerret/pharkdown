defmodule Pharkdown.FormatterTest do
  
  use ExUnit.Case

  alias Pharkdown.Engine
  alias Pharkdown.Formatter

  alias Transformer, as: T
  
  doctest Pharkdown.Formatter

  test "un environnement blockcode n'est pas corrigé" do
    code = """
    ~~~
    Un *italique* non corrigé.
    Avec du `code`.
    Et un [lien](vers/cible)
    ~~~
    """
    actual = Engine.compile_string(code)
    expect = """
    <pre><code lang="">
    Un *italique* non corrigé.
    Avec du `code`.
    Et un [lien](vers/cible)
    </code></pre>
    """
    assert actual == String.trim(expect)
  end

  describe "Les lignes HR" do

    test "une ligne simple" do
      code = "---"
      actual = Engine.compile_string(code)
      expect = "<hr/>"
      assert actual == expect
      
      code = "***"
      actual = Engine.compile_string(code)
      expect = "<hr/>"
      assert actual == expect
    end 

    test "ligne avec paramètres string" do
      code = "---height:10px---"
      actual = Engine.compile_string(code)
      expect = "<hr style=\"height:10px\"/>"
      assert actual == expect
    end

    test "ligne avec paramètres Map" do
      code = ~s(---{"height": "10px"}---)
      actual = Engine.compile_string(code)
      expect = "<hr style=\"height:10px;\"/>"
      assert actual == expect

      code = ~s(***{"height": "10px"}***)
      actual = Engine.compile_string(code)
      expect = "<hr style=\"height:10px;\"/>"
      assert actual == expect
    end

    test "ligne avec class CSS" do
      code = "---.classCss---"
      actual = Engine.compile_string(code)
      expect = ~s(<hr class="classCss"/>)
      assert actual == expect

      code = "***.classCss***"
      actual = Engine.compile_string(code)
      expect = ~s(<hr class="classCss"/>)
      assert actual == expect
    end

    test "ligne avec plusieurs classes CSS" do
      code = "---.css1.css2.class3---"
      actual = Engine.compile_string(code)
      expect = ~s(<hr class="css1 css2 class3"/>)
      assert actual == expect

      code = "***.css1.css2.class3***"
      actual = Engine.compile_string(code)
      expect = ~s(<hr class="css1 css2 class3"/>)
      assert actual == expect
    end
    
  end #/describe lignes HR
end
