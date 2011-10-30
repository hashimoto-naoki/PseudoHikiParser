#/usr/bin/env ruby

require 'test/unit'
require 'lib/pseudohiki/inlineparser'


class TC_InlineParser < Test::Unit::TestCase
  include PseudoHiki

  def test_inlineparser_compile_token_pat
    parser = InlineParser.new("")
    assert_equal(/'''|\{\{|''|\[\[|==|\}\}|\]\]|\|/,parser.token_pat)
  end

  def test_inlineparser_split_into_tokens
    parser = InlineParser.new("")
    tokens = parser.split_into_tokens("As a test case, '''this part''' must be in <strong>.")
    assert_equal(["As a test case, ","'''","this part","'''"," must be in <strong>."],tokens)
    tokens = parser.split_into_tokens("As another {{test case}}, '''this part''' must be in <strong>.")
    assert_equal(["As another ","{{","test case","}}", ", ","'''","this part","'''"," must be in <strong>."],tokens)
    tokens = parser.split_into_tokens("As another ''test case'', '''this part''' must be in <strong>.")
    assert_equal(["As another ","''","test case","''", ", ","'''","this part","'''"," must be in <strong>."],tokens)
  end

  def test_inlineparser_parse
    parser = InlineParser.new("As {{''another test'' case}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another test"]], [" case"]], [", "], [["this part"]], [" must be in <strong>."]],tree)
    parser = InlineParser.new("this is a line that ends with a {{node}}")
    tree = parser.parse.tree
    assert_equal([["this is a line that ends with a "],[["node"]]],tree)
    parser = InlineParser.new("this is another line that ends with a {{node")
    tree = parser.parse.tree
    assert_equal([["this is another line that ends with a "],[["node"]]],tree)
  end

  def test_inlineparser_convert_last_node_into_leaf
    parser = InlineParser.new("this is another line that ends with a {{node")
    stack = parser.parse
    assert_equal([["this is another line that ends with a "],[["node"]]],stack.tree)
    stack.convert_last_node_into_leaf
    assert_equal([["this is another line that ends with a "],["{{"], ["node"]],stack.tree)
    parser = InlineParser.new("As {{''another '''test'' case}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another "], ["'''"], ["test"]], [" case"]], [", "], [["this part"]], [" must be in <strong>."]],tree)
    parser = InlineParser.new("As {{''another ]]test case with a [[node]]''.}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another "], ["]]"], ["test case with a "], [["node"]]], ["."]], [", "], [["this part"]], [" must be in <strong>."]],tree)
    parser = InlineParser.new("As {{''another {{test'' case}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another "], ["{{"], ["test"]], [" case"]], [", "], [["this part"]], [" must be in <strong>."]],tree)
  end
end

class TC_HtmlFormat < Test::Unit::TestCase
  include PseudoHiki

  def test_visit_linknode
    formatter = HtmlFormat.create_plain

    parser = InlineParser.new("[[image.html]] is a link to a html file.")
    tree = parser.parse.tree
    assert_equal('<a href="image.html">image.html</a> is a link to a html file.', tree.accept(formatter).to_s)

    parser = InlineParser.new("[[LINK|image.html]] is a link to a html file.")
    tree = parser.parse.tree
    assert_equal('<a href="image.html">LINK</a> is a link to a html file.', tree.accept(formatter).to_s)
    assert_equal('<a href="image.html">LINK</a> is a link to a html file.', tree.accept(formatter).to_s)

    parser = InlineParser.new("[[an explanation about {{co2}}|co2.html]] is a link to a html file.")
    tree = parser.parse.tree
    assert_equal('<a href="co2.html">an explanation about <span>co2</span></a> is a link to a html file.', tree.accept(formatter).to_s)
    assert_equal('<a href="co2.html">an explanation about <span>co2</span></a> is a link to a html file.', tree.accept(formatter).to_s)

    parser = InlineParser.new("[[image name|image.png]] is a link to a image file.")
    tree = parser.parse.tree
    assert_equal("<img alt=\"image name\" src=\"image.png\">\n is a link to a image file.", tree.accept(formatter).to_s)

    parser = InlineParser.new("[[image.png]] is a link to a image file.")
    tree = parser.parse.tree
    assert_equal("<img src=\"image.png\">\n is a link to a image file.", tree.accept(formatter).to_s)
  end

  def test_visit_leafnode
    formatter = HtmlFormat.create_plain
    parser = InlineParser.new("a string with <charactors> that are replaced by &entity references.")
    tree = parser.parse.tree
    assert_equal("a string with &lt;charactors&gt; that are replaced by &amp;entity references.", tree.accept(formatter).to_s)
    parser = InlineParser.new("a string with a token |.")
    tree = parser.parse.tree
    assert_equal("a string with a token |.", tree.accept(formatter).to_s)
  end

  def test_visit_pluginnode
    formatter = HtmlFormat.create_plain
    tree = InlineParser.new("{{co2}} represents the carbon dioxide.").parse.tree
    assert_equal("<span>co2</span> represents the carbon dioxide.",tree.accept(formatter).to_s)
  end
end
