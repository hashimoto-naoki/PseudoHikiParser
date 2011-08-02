#/usr/bin/env ruby

require 'test/unit'
require 'lib/pseudohiki/inlineparser'


class TC_PsudoHikiInlineParser < Test::Unit::TestCase
  def test_compile_token_pat
    parser = PseudoHikiInlineParser.new
    assert_equal(/'''|\[\[|''|==|\{\{|\}\}|\]\]/,parser.token_pat)
  end

  def test_split_into_tokens
    parser = PseudoHikiInlineParser.new
    tokens = parser.split_into_tokens("As a test case, '''this part''' must be in <strong>.")
    assert_equal(["As a test case, ","'''","this part","'''"," must be in <strong>."],tokens)
    tokens = parser.split_into_tokens("As another {{test case}}, '''this part''' must be in <strong>.")
    assert_equal(["As another ","{{","test case","}}", ", ","'''","this part","'''"," must be in <strong>."],tokens)
    tokens = parser.split_into_tokens("As another ''test case'', '''this part''' must be in <strong>.")
    assert_equal(["As another ","''","test case","''", ", ","'''","this part","'''"," must be in <strong>."],tokens)
  end

  def test_parse
    parser = PseudoHikiInlineParser.new("As {{''another test'' case}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another test"]], [" case"]], [", "], [["this part"]], [" must be in <strong>."]],tree)
    parser = PseudoHikiInlineParser.new("this is a line that ends with a {{node}}")
    tree = parser.parse.tree
    assert_equal([["this is a line that ends with a "],[["node"]]],tree)
    parser = PseudoHikiInlineParser.new("this is another line that ends with a {{node")
    tree = parser.parse.tree
    assert_equal([["this is another line that ends with a "],[["node"]]],tree)
  end

  def test_inlinestack_convert_last_node_into_leaf
    parser = PseudoHikiInlineParser.new("this is another line that ends with a {{node")
    stack = parser.parse
    assert_equal([["this is another line that ends with a "],[["node"]]],stack.tree)
    stack.convert_last_node_into_leaf
    assert_equal([["this is another line that ends with a "],["{{"], ["node"]],stack.tree)
    parser = PseudoHikiInlineParser.new("As {{''another '''test'' case}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another "], ["'''"], ["test"]], [" case"]], [", "], [["this part"]], [" must be in <strong>."]],tree)
    parser = PseudoHikiInlineParser.new("As {{''another ]]test case with a [[node]]''.}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another "], ["]]"], ["test case with a "], [["node"]]], ["."]], [", "], [["this part"]], [" must be in <strong>."]],tree)
    parser = PseudoHikiInlineParser.new("As {{''another {{test'' case}}, '''this part''' must be in <strong>.")
    tree = parser.parse.tree
    assert_equal([["As "], [[["another "], ["{{"], ["test"]], [" case"]], [", "], [["this part"]], [" must be in <strong>."]],tree)
  end
end

