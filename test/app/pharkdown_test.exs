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

  test "Du code EEx répété doit être bien traité" do
    code = """
    <%= un code %>
    <%= un code %>
    `<%= un code %>`
    """
    actual = Engine.compile_string(code)
    expect = """
    <div class="p"><%= un code %></div>
    <div class="p"><%= un code %></div>
    <div class="p"><code><%= un code %></code></div>
    """ |> String.trim()
    assert actual == expect
  end

  test "Du code EEx sans sortie ne doit pas générer un paragraphe" do
    code = "<% 2 + 4 %>"
    actual = Engine.compile_string(code)
    expect = "<% 2 + 4 %>"
    assert actual == expect

    code = """
    Un paragraphe.
    <% 2 + 4 %>
    Un autre paragraphe.
    """
    actual = Engine.compile_string(code)
    expect = """
    <div class="p">Un paragraphe.</div>
    <% 2 + 4 %>
    <div class="p">Un autre paragraphe.</div>
    """ |> String.trim()
    assert actual == expect
  end

  test "Traitement correct des codes dans le texte" do
    code = """
    ## Titre de niveau 2
    `## Titre de niveau 2`
    """
    expect = """
    <h2>Titre de niveau 2</h2>
    <div class="p"><code>## Titre de niveau 2</code></div>
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
