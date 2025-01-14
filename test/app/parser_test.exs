defmodule Pharkdown.ParserTest do
  
  use ExUnit.Case

  alias Pharkdown.Parser
  
  doctest Pharkdown.Parser

  test "Environnement document" do
    code    = "document/\nPremière ligne\nDeuxième ligne\n/document"
    expect  = [
      {
        :environment, 
        [
          type: :document,
          content: [
            [type: :paragraph, content: "Première ligne"],
            [type: :paragraph, content: "Deuxième ligne"]
          ]
        ]
      }
    ]
    assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)
  end

  test "Environnement avec clé réduite ('doc' pour 'document')" do
    code    = "doc/\nPremière ligne\nDeuxième ligne\n/doc"
    expect  = [
      {
        :environment, 
        [
          type: :document, 
          content: [
            [type: :paragraph, content: "Première ligne"],
            [type: :paragraph, content: "Deuxième ligne"]
          ]
    ]
      }
    ]
    assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)
  end

  # # C'est celui du doctest
  # test "Environnement document avec une phrase suivante" do
  #   code = "document/\nPremière ligne\nDeuxième ligne\n/document\nAutre paragraphe"
  #   actual = Parser.tokenize(code)
  #   expect = [
  #     {:environment, [content: "Première ligne\nDeuxième ligne", type: :document]},
  #     {:paragraph, [content: "Autre paragraphe"]}
  #   ]
  #   assert expect == actual
  # end

  # # Celui du @doctest
  # test "Les tokens sont remis dans le bon ordre" do
  #   code = "document/\nLa ligne\n/document\n## Le sous-titre"
  #   actual = Parser.tokenize(code)
  #   expect = [
  #     {:environment, [content: "La ligne", type: :document]},
  #     {:title, [content: "Le sous-titre", level: 2]}
  #   ]
  #   assert actual == expect
  # end

  test "listes multi niveaux" do
    code = """
    * item 1
    ** item 1.1
    * item 2
    * item 3
    ** item 3.1
    ** item 3.2
    """
    expect = [
      {:list, [type: :regular, first: nil, content: [
        [content: "item 1", level: 1],
        [content: "item 1.1", level: 2],
        [content: "item 2", level: 1],
        [content: "item 3", level: 1],
        [content: "item 3.1", level: 2],
        [content: "item 3.2", level: 2]
      ]]}
    ]
    assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)

  end

  test "liste numérotée" do
    code = "1- Item 1\n- Item 2\n- Item 3\nUn paragraphe"
    expect = [
      {:list, [type: :ordered, first: 1, content: [
        [content: "Item 1", level: 1],
        [content: "Item 2", level: 1],
        [content: "Item 3", level: 1]
      ]]},
      {:paragraph, [content: "Un paragraphe"]}
    ]
    assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)
  end

  test "Liste numérotée partant d'un grand nombre" do
    code = "233- Item 1\n- Item 2\nUn paragraphe"
    expect = [
      {:list, [type: :ordered, first: 233, content: [
        [content: "Item 1", level: 1],
        [content: "Item 2", level: 1]
      ]]},
      {:paragraph, [content: "Un paragraphe"]}
    ]
    assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)
  end

  test "Liste numérotée commençant à 5" do
    code = "5- Item 1\n-- Item 2"
    expect = [
      {:list, [type: :ordered, first: 5, content: [
        [content: "Item 1", level: 1],
        [content: "Item 2", level: 2]
      ]]}
    ]
    assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)
  end

  test "Liste avec un environnement" do
    code = """
    * Item 1
    doc/
    Mon document
    /doc
    * Item 2
    """
    doc_env = {
      :environment, 
      [
        type: :document, 
        content: [[type: :paragraph, content: "Mon document"]]
      ]}
    expect = [
      {
        :list, [
          type: :regular, first: nil, 
          content: [
            [content: "Item 1", level: 1],
            [content: doc_env],
            [content: "Item 2", level: 1]
          ]
        ]
      }
    ]
    assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)
  end

  test "Liste avec environnement et indentation" do
    code = """
    * Item 1
      doc/
      Mon document
      /doc
    * Item 2
    """
    doc_env = {:environment, [type: :document, content: [[type: :paragraph, content: "Mon document"]]]}
    expect = [
      {
        :list, [
          type: :regular, first: nil, 
          content: [
            [content: "Item 1", level: 1],
            [content: doc_env],
            [content: "Item 2", level: 1]
          ]
        ]
      }
    ]
    # assert expect == Parser.tokenize(code)
    assert expect == Parser.parse(code)
  end
end
