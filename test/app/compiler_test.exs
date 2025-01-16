defmodule Pharkdown.CompilerTest do
  
  use ExUnit.Case

  alias Pharkdown.Engine
  
  doctest Engine

  test "un environnement blockcode n'est pas corrigé" do
    code = """
    ```
    Un *italique* non corrigé.
    Avec du `code`.
    Et un [lien](vers/cible)
    ```
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

  test "Environnement document" do
    code = """
    ~document
    L'intérieur du document.
    document~
    """
  end

end
