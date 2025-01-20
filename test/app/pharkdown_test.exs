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
    <%= un code %>
    <%= un code %>
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

  describe "Traitement des fonctions personnalisées" do

    test "une fonction simple sur une ligne est évaluée" do
      code = "ma_fonction()"
      actual = Engine.compile_string(code)
      expect = "<div class=\"p\">Le retour de la fonction</div>"
      assert actual == expect
    end

    test "une fonction 'post' n'est évaluée qu'à la fin" do

      code = "post/fonction_post()"
      actual = Engine.compile_string(code)
      expect = "<div class=\"p\">*non traité*</div>"
      assert actual == expect
      
      # La même sans être "post"
      code = "fonction_post()"
      actual = Engine.compile_string(code)
      expect = "<div class=\"p\"><em>non traité</em></div>"
      assert actual == expect
    
    end

    test "les paramètres d'une fonction sont bien traités" do
      code = "dit([Bonjour, tout, le, monde])"
      actual = Engine.compile_string(code)
      expect = "<div class=\"p\">Bonjour tout le monde</div>"
      assert actual == expect
    end

    # Ce test passe quand il veut………
    # test "une fonction avec paramètres variés ne produira pas le résultat attendu" do
    #   code    = "traite(12, true, [1\\, 2\\, 3])"
    #   actual  = Engine.compile_string(code)
    #   expect  = ~s(<div class="p">12, vrai et la liste ["1, 2, 3"]</div>)
    #   assert actual == expect
    # end

    test "on peut utiliser les fonctions générales communes" do
      code = "red(Ce texte doit être en rouge)"
      actual = Engine.compile_string(code)
      expect = ~s(<div class="p"><span style="color:red;">Ce texte doit être en rouge</span></div>)
      assert actual == expect

      code = "color(Ce texte doit être dans ma couleur, 55F25E)"
      actual = Engine.compile_string(code)
      expect = ~s(<div class="p"><span style="color:#55F25E;">Ce texte doit être dans ma couleur</span></div>)
      assert actual == expect

    end

  end #/describe fonctions personnalisées


  test "Deux blocs de code qui s'enchainent" do
    code = """
    ~~~
    Un premier code
    ~~~

    Un paragraphe.

    ~~~
    Un autre code
    ~~~
    """
    actual = Engine.compile_string(code)
    expect = """
    <pre><code lang="">
    Un premier code
    </code></pre>
    <div class="p">Un paragraphe.</div>
    <pre><code lang="">
    Un autre code
    </code></pre>
    """ |> String.trim()

    assert actual == expect
  end

  test "Deux blocs de code qui s'enchainent, avec des langues" do
    code = """
    ~~~elixir
    Un premier code
    ~~~

    Un paragraphe.

    ~~~html
    Un autre code
    ~~~
    """
    actual = Engine.compile_string(code)
    expect = """
    <pre><code lang="elixir">
    Un premier code
    </code></pre>
    <div class="p">Un paragraphe.</div>
    <pre><code lang="html">
    Un autre code
    </code></pre>
    """ |> String.trim()

    assert actual == expect
  end


  test "Une fonction dans un bloc de code ne doit pas être appelée" do
    code = """
    ~~~elixir
    rien(["bonjour", "tout", "le", "monde"])
    ~~~
    """
    actual = Engine.compile_string(code)
    expect = """
    <pre><code lang="elixir">
    rien(["bonjour", "tout", "le", "monde"])
    </code></pre>
    """ |> String.trim()
    assert actual == expect
  end

  test "Une fonction dans DEUX blocs de code ne doit pas être appelée" do
    code = """
    Paragraphe 1.
    ~~~elixir
    rien(["bonjour", "tout", "le", "monde"])
    ~~~
    Paragraphe 2.
    ~~~html
    autre_rien(["bonjour", "tout", "le", "monde"])
    ~~~
    Paragraphe 3.
    """
    actual = Engine.compile_string(code)
    expect = """
    <div class="p">Paragraphe 1.</div>
    <pre><code lang="elixir">
    rien(["bonjour", "tout", "le", "monde"])
    </code></pre>
    <div class="p">Paragraphe 2.</div>
    <pre><code lang="html">
    autre_rien(["bonjour", "tout", "le", "monde"])
    </code></pre>
    <div class="p">Paragraphe 3.</div>
    """ |> String.trim()
    assert actual == expect
  end



end

# --- Pour tester les fonctions personnalisées ---
defmodule Pharkdown.Helpers do
  def ma_fonction() do
    "Le retour de la fonction"
  end
  def fonction_post() do
    "*non traité*"
  end
  def dit(liste) do
    Enum.join(liste, " ")
  end

  def traite(chiffre, booleen, liste) when is_integer(chiffre) and is_boolean(booleen) and is_list(liste) do
    "#{chiffre}, #{booleen && "vrai" || "false"} et la liste #{inspect liste}"
  end
end
