defmodule Pharkdown.LoaderTest do
  
  use ExUnit.Case
  
  doctest Pharkdown.Loader

  alias Pharkdown.Loader

  @options [template_folder: "./test/fixtures/textes"]

  test "insertion simple d'un texte" do
    res = Loader.load_external_contents("load(simple.phad)", @options)
    exp = "Un simple paragraphe."
    assert res == exp
  end

  test "insertion simple d'un code" do
    res = Loader.load_external_contents("load_as_code(simple.rb)", @options)
    exp = """
    ~~~ruby
    <span class=\"text-sm italic\">(source : ./test/fixtures/textes/simple.rb)</span>
    
    module MonModule

    end
    ~~~
    """
    assert res == exp
  end

  test "insertion d'un texte dans un autre texte existant" do
    txt = """
    Un premier paragraphe.

    load(simple.phad)

    Un paragraphe après.
    """
    res = Loader.load_external_contents(txt, @options)
    exp = """
    Un premier paragraphe.

    Un simple paragraphe.

    Un paragraphe après.
    """
    assert res == exp
  end

  test "insertion d'un bloc de code dans un texte" do
    txt = """
    Un premier paragraphe.

    load_as_code(simple.rb)

    Le paragraphe après le code.
    """

    res = Loader.load_external_contents(txt, @options)

    exp = """
    Un premier paragraphe.

    ~~~ruby
    <span class=\"text-sm italic\">(source : ./test/fixtures/textes/simple.rb)</span>
    
    module MonModule

    end
    ~~~

    Le paragraphe après le code.
    """

    assert res == exp
  end

  test "on ne touche pas le texte qui ne contient pas de load" do
    txt = "Un texte sans load.\n\n\n\n"
    res = Loader.load_external_contents(txt, @options)
    exp = "Un texte sans load.\n\n"
    assert res == exp
  end
end
