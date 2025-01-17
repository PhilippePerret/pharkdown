defmodule PharkdownTest do
  use ExUnit.Case

  doctest Pharkdown

  alias Pharkdown.Parser

  test "Une ligne complètement en italique" do
    code = """
    Un premier paragraphe
    *Une ligne complètement en italiques*
    Un autre paragraphe.
    """
    actual = Parser.parse(code)
    expect = [
      {:paragraph, [content: "Un premier paragraphe"]},
      {:paragraph, [content: "*Une ligne complètement en italiques*"]},
      {:paragraph, [content: "Un autre paragraphe."]}
    ]
    assert actual == expect

  end

  describe "Sans l'option :smarties" do
    test "les guillemets ne se corrigent pas" do
      # Ils se corrigent en temps normal
      code = "Des \"guillemets\" !"
      actual = Pharkdown.Engine.compile_string(code)
      expect = "<div class=\"p\">Des <nowrap>« guillemets » !</nowrap>"
      assert actual == expect

      Application.put_env(:pharkdown, :options, [{:smarties, false}])
      # Ils ne se corrigent plus
      code = "Des \"guillemets\" !"
      actual = Pharkdown.Engine.compile_string(code)
      expect = "<div class=\"p\">Des <nowrap>\"guillemets\" !</nowrap>"
      assert actual == expect

    end
  end
end
