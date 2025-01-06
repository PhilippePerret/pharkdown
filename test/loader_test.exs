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

end
