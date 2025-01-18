defmodule PharkdownTest do
  use ExUnit.Case

  doctest Pharkdown

  alias Pharkdown.{Engine, Parser}
  alias Transformer, as: T

  test "Un bloc de code ne doit (presque) pas être touché" do
    code = """
    Un *paragraphe*.
    ~~~elixir
    Du code <balise> est *italique*.
    Plusieurs [liens](pour/voir) avec
    .css: des "guillemets" et 'apostrophes'
    ~~~
    .css: Un autre **paragraphe**.
    """
    expect = """
    <div class="p">Un <em>paragraphe</em>.</div>
    <pre><code lang="elixir">
    Du code &lt;balise> est *italique*.
    Plusieurs [liens](pour/voir) avec
    .css: des "guillemets" et 'apostrophes'
    </code></pre>
    <div class="p css">Un autre <strong>paragraphe</strong>.</div>
    """ |> String.trim()
    actual = Engine.compile_string(code)
    assert actual == expect
  end

  test "Une ligne complètement en italique" do
    # C'était un cas problématique
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
      expect = "<div class=\"p\">Des <nowrap>« guillemets » !</nowrap></div>" |> T.h()
      assert actual == expect

      Application.put_env(:pharkdown, :options, [{:smarties, false}])
      # Ils ne se corrigent plus
      code = "Des \"guillemets\" !"
      actual = Pharkdown.Engine.compile_string(code)
      expect = "<div class=\"p\">Des <nowrap>\"guillemets\" !</nowrap></div>" |> T.h()
      assert actual == expect

    end
  end
end
