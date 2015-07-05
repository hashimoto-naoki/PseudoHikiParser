#!/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/pseudohiki/blockparser'
require 'lib/pseudohiki/htmlformat'
require 'lib/pseudohiki/autolink'

class TC_WikiName < MiniTest::Unit::TestCase
  include PseudoHiki


  def test_link_only_url
    text = <<TEXT
a line with a url http://www.example.org/ and a WikiName.
TEXT

    xhtml = <<HTML
<p>
a line with a url <a href="http://www.example.org/">http://www.example.org/</a> and a WikiName.
</p>
HTML
    auto_linker = AutoLink::WikiName.new({:wiki_name => false})
    tree = BlockParser.parse(text.lines.to_a, auto_linker)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_link_wiki_name
    text = <<TEXT
a line with a url http://www.example.org/ , an ^EscapedWikiName and a WikiName.
TEXT

    xhtml = <<HTML
<p>
a line with a url <a href="http://www.example.org/">http://www.example.org/</a> , an ^<a href="EscapedWikiName">EscapedWikiName</a> and a <a href="WikiName">WikiName</a>.
</p>
HTML
    auto_linker = AutoLink::WikiName.new
    tree = BlockParser.parse(text.lines.to_a, auto_linker)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_escape_wiki_name
    text = <<TEXT
a line with a url http://www.example.org/ , an ^EscapedWikiName and a WikiName.
TEXT

    xhtml = <<HTML
<p>
a line with a url <a href="http://www.example.org/">http://www.example.org/</a> , an EscapedWikiName and a <a href="WikiName">WikiName</a>.
</p>
HTML
    auto_linker = AutoLink::WikiName.new({:wiki_name => true, :escape_wiki_name => true})
    tree = BlockParser.parse(text.lines.to_a, auto_linker)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_link_only_wiki_name
    text = <<TEXT
a line with a url http://www.example.org/ , an ^EscapedWikiName and a WikiName.
TEXT

    xhtml = <<HTML
<p>
a line with a url http://www.example.org/ , an EscapedWikiName and a <a href="WikiName">WikiName</a>.
</p>
HTML
    auto_linker = AutoLink::WikiName.new({:url => false, :wiki_name => true, :escape_wiki_name => true})
    tree = BlockParser.parse(text.lines.to_a, auto_linker)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_link_wiki_name_in_quote
    text = <<TEXT
""a line with a url http://www.example.org/ , an ^EscapedWikiName and a WikiName.
TEXT

    xhtml = <<HTML
<blockquote>
<p>
a line with a url <a href="http://www.example.org/">http://www.example.org/</a> , an EscapedWikiName and a <a href="WikiName">WikiName</a>.
</p>
</blockquote>
HTML
    auto_linker = AutoLink::WikiName.new({:wiki_name => true, :escape_wiki_name => true})
    tree = BlockParser.parse(text.lines.to_a, auto_linker)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end
end
