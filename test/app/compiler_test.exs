defmodule Pharkdown.CompilerTest do
  
  use ExUnit.Case

  alias Pharkdown.Engine
  
  doctest Engine

  test "un environnement blockcode n'est pas corrigé" do
    code = """
    code/
    Un *italique* non corrigé.
    Avec du `code`.
    Et un [lien](vers/cible)
    /code
    """
    actual = Engine.compile_string(code)
    expect = """
    <pre><code>
    Un *italique* non corrigé.
    Avec du `code`.
    Et un [lien](vers/cible)
    </code></pre>
    """
    assert actual == expect
  end

end
