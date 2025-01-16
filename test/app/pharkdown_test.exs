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
end
