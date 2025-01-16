defmodule Pharkdown.CompilerTest do
  
  use ExUnit.Case

  alias Pharkdown.Engine
  
  doctest Engine

  test "L'intérieur d'un environnement blockcode n'est pas corrigé" do
    code = """
    Un paragraphe avant.
    ```
    Un *italique* non corrigé.
    Avec du `code`.
    Et un [lien](vers/cible)
    ```
    Un paragraphe après.
    """
    actual = Engine.compile_string(code)
    expect = """
    <div class="p">Un paragraphe avant.</div>
    <pre><code>
    Un *italique* non corrigé.
    Avec du `code`.
    Et un [lien](vers/cible)
    </code></pre>
    <div class="p">Un paragraphe après.</div>
    """
    assert actual == expect
  end

  test "L'intérieur d'un environnement document est corrigé" do
    code = """
    ~document
    L'intérieur du document *corrigé*.
    Même les [liens](path/to/ca.html).
    .css: Le paragraphe stylisé.
    document~
    """
    actual = Engine.compile_string(code)
    expect = """
    <section data-env="document" class="document">
    <div class="p">L'intérieur du document <em>corrigé</em>.</div>
    <div class="p">Même les <a href="path/to/ca.html">liens</a>.</div>
    <div class="p css">Le paragraphe stylisé.</div>
    </section>
    """
    assert actual == expect
  end

end
