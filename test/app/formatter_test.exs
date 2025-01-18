defmodule Pharkdown.FormatterTest do
  
  use ExUnit.Case

  alias Pharkdown.Engine
  # alias Pharkdown.Formatter

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

end
