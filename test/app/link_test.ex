defmodule Pharkdown.LinkTests do

  use ExUnit.Case

  alias Pharkdown.{Link, Params}

  doctest Pharkdown.Link
  doctest Pharkdown.Params

  test "ne retourne pas ce qui est prévu" do
    code = "[explorer_markdown_html/page-test.phad](/explorer/markdown/?ipage=2)"
    actual = Link.treate_links_in(code)
    expect = ~s(<a href="/explorer/markdown/?ipage=2">explorer_markdown_html/page-test.phad</a>)
    assert actual == expect
  end

end