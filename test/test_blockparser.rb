#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/pseudohiki/blockparser'

class TC_BlockLeaf < MiniTest::Unit::TestCase
  include PseudoHiki::BlockParser::BlockElement

  def test_block_when_descnode
    assert_equal(DescNode, DescLeaf.new.block)
  end

  def test_block_when_headingleaf
    assert_equal(HeadingNode, HeadingLeaf.new.block)
  end

  def test_block_head_re_when_verbatimleaf
    assert_equal(/\A\s/o, VerbatimLeaf.new.head_re)
  end

  def test_block_head_re_when_tableleaf
    assert_equal(/\A\|\|/o, TableLeaf.new.head_re)
  end

  def test_block_head_re_when_commentoutleaf
    assert_equal(/\A\/\//o.to_s, CommentOutLeaf.new.head_re.to_s)
  end

  def test_block_head_re_when_commentoutleaf2
    assert_equal(/\A(\/\/)/o, /\A(\/\/)/o)
  end

  def test_block_head_re_when_headingleaf
    assert_equal(/\A!+/o, HeadingLeaf.new.head_re)
  end

  def test_leaf_create
    parser = PseudoHiki::BlockParser.new
    paragraph_line = "This is a paragraph."
    paragraph = parser.select_leaf_type(paragraph_line).create(paragraph_line)
    assert_equal([paragraph_line], paragraph)
    assert_equal(nil, paragraph.level)
  end

  def test_nestedleaf_create
    parser = PseudoHiki::BlockParser.new
    level1_heading_line = "!This is a level1 heading."
    heading1 = parser.select_leaf_type(level1_heading_line).create(level1_heading_line)
    assert_equal([["This is a level1 heading."]], heading1)
    assert_equal(1, heading1.level)

    level2_heading_line = "!!This is a level2 heading."
    heading2 = parser.select_leaf_type(level2_heading_line).create(level2_heading_line)
    assert_equal([["This is a level2 heading."]], heading2)
    assert_equal(2, heading2.level)
  end

  def test_select_leaf_type
    parser = PseudoHiki::BlockParser.new
    assert_equal(ParagraphLeaf, parser.select_leaf_type("This is a paragraph type line."))
    assert_equal(DescLeaf, parser.select_leaf_type(': This is a desc type line.'))
    assert_equal(VerbatimLeaf, parser.select_leaf_type(" This is a verbatim type line."))
    assert_equal(QuoteLeaf, parser.select_leaf_type('"" This is a quote type line.'))
    assert_equal(TableLeaf, parser.select_leaf_type('|| This is a table type line.'))
    assert_equal(CommentOutLeaf, parser.select_leaf_type('// This is a commentout type line.'))
    assert_equal(HeadingLeaf, parser.select_leaf_type("!This is a heading type line."))
    assert_equal(ListLeaf, parser.select_leaf_type("*This is a list type line."))
    assert_equal(ListLeaf, parser.select_leaf_type("**This is another list type line."))
    assert_equal(EnumLeaf, parser.select_leaf_type("#This is a list type line."))
    assert_equal(EnumLeaf, parser.select_leaf_type("##This is another list type line."))
    assert_equal(HrLeaf, parser.select_leaf_type("----"))
    assert_equal(BlockNodeEnd, parser.select_leaf_type("\n"))
    assert_equal(BlockNodeEnd, parser.select_leaf_type("\r\n"))
  end

  def create_leaf(str)
    parser = PseudoHiki::BlockParser.new
    parser.select_leaf_type(str).create(str)
  end

  def test_push_leaf
    paragraph_str = "This is a paragraph line."
    another_paragraph_str = "This is another paragraph line."
    stack = PseudoHiki::BlockParser.new.stack
    stack.push create_leaf(paragraph_str)
    paragraph_tree = stack.tree
    assert_equal([[[paragraph_str]]],paragraph_tree)
    assert_equal(nil,paragraph_tree.first.level)
    another_paragraph = create_leaf(another_paragraph_str)
    stack.push another_paragraph
    assert_equal([[[paragraph_str,
                   another_paragraph_str]]],paragraph_tree)

    heading_str = "This is a heading line."
    stack = PseudoHiki::BlockParser.new.stack
    stack.push create_leaf("!"+heading_str)
    heading_tree = stack.tree
#    heading_tree = push_leaf_on_stack("!"+heading_str).tree
    assert_equal(1,heading_tree.first.level)
    assert_equal(HeadingNode, heading_tree.first.class)
    assert_equal(HeadingLeaf, heading_tree.first.first.class)
    stack.push create_leaf("!!"+heading_str)
    assert_equal([[[[heading_str]],
                   [[[heading_str]]]]], heading_tree)

    stack = PseudoHiki::BlockParser.new.stack
    stack.push create_leaf("!!"+heading_str)
    heading2_tree = stack.tree
    assert_equal([[[[heading_str]]]], heading2_tree)
    assert_equal(2,heading2_tree.first.level)

    stack = PseudoHiki::BlockParser.new.stack
    stack.push create_leaf("!"+heading_str)
    stack.push create_leaf(another_paragraph_str)
    assert_equal([[[[heading_str]],
                   [[another_paragraph_str]]]],stack.tree)
  end

  def test_paragraph_breakable?
    paragraph_leaf = create_leaf("paragraph leaf")
    blocknode_end = create_leaf("\n")
    heading1_leaf = create_leaf("!heading1 leaf")
    heading2_leaf = create_leaf("!!heaindg2 leaf")

    parser = PseudoHiki::BlockParser.new
    parser.stack.push paragraph_leaf
    assert_equal(true, parser.breakable?(heading1_leaf))
    assert_equal(false, parser.breakable?(paragraph_leaf))
    assert_equal(true, parser.breakable?(blocknode_end))
  end

  def test_heading1_breakable?
    paragraph_leaf = create_leaf("paragraph leaf")
    blocknode_end = create_leaf("\n")
    heading1_leaf = create_leaf("!heading1 leaf")
    heading2_leaf = create_leaf("!!heaindg2 leaf")

    parser = PseudoHiki::BlockParser.new
    parser.stack.push heading1_leaf
    assert_equal(true, parser.breakable?(heading1_leaf))
    assert_equal(false, parser.breakable?(heading2_leaf))
    assert_equal(false, parser.breakable?(blocknode_end))
  end

  def test_heading2_breakable?
    paragraph_leaf = create_leaf("paragraph leaf")
    blocknode_end = create_leaf("\n")
    heading1_leaf = create_leaf("!heading1 leaf")
    heading2_leaf = create_leaf("!!heaindg2 leaf")

    parser = PseudoHiki::BlockParser.new
    parser.stack.push heading2_leaf
    assert_equal(true, parser.breakable?(heading1_leaf))
    assert_equal(true, parser.breakable?(heading2_leaf))
    assert_equal(false, parser.breakable?(blocknode_end))
  end

  def test_list1_breakale?
    paragraph_leaf = create_leaf("paragraph leaf")
    blocknode_end = create_leaf("\n")
    list1_leaf = create_leaf("*list1 leaf")
    list2_leaf = create_leaf("**list2 leaf")

    parser = PseudoHiki::BlockParser.new
    parser.stack.push list1_leaf
    assert_equal(true, parser.breakable?(blocknode_end))
    assert_equal(true, parser.breakable?(list1_leaf))
    assert_equal(false, parser.breakable?(list2_leaf))
    parser.stack.pop
    assert_equal(false, parser.breakable?(list1_leaf))
  end

  def test_list2_breakale?
    paragraph_leaf = create_leaf("paragraph leaf")
    blocknode_end = create_leaf("\n")
    list1_leaf = create_leaf("*list1 leaf")
    list2_leaf = create_leaf("**list2 leaf")

    parser = PseudoHiki::BlockParser.new
    parser.stack.push list2_leaf
    current_node_superclass = parser.stack.current_node.class.superclass
    leaf_superclass = list1_leaf.block.superclass
    assert_equal(2, parser.stack.current_node.level)
    assert_equal(ListNode, list1_leaf.block)
    assert_equal(1, list1_leaf.level)
    assert_equal(ListNode, list2_leaf.block)
    assert_equal(2, list2_leaf.level)
    assert_equal(ListWrapNode, parser.stack.current_node.class)
#    assert_equal(true, parser.stack.current_node.class.kind_of?(PseudoHiki::BlockParser::ListTypeBlockNode))
    assert_equal(PseudoHiki::BlockParser::ListLeafNode, current_node_superclass)
    assert_equal(PseudoHiki::BlockParser::ListTypeBlockNode, leaf_superclass)
    assert_equal(false, current_node_superclass == leaf_superclass)
    assert_equal(true, PseudoHiki::BlockParser::ListTypeBlockNode == leaf_superclass)
    assert_equal(true, parser.breakable?(blocknode_end))
    assert_equal(false, parser.stack.current_node.level <= list1_leaf.level)
    assert_equal(true, parser.stack.current_node.level <= list2_leaf.level)
    assert_equal(true, parser.breakable?(list1_leaf))
    assert_equal(true, parser.breakable?(list2_leaf))
    parser.stack.pop
    assert_equal(ListNode, parser.stack.current_node.class)
    assert_equal(true, parser.stack.current_node.class.superclass == leaf_superclass)
    assert_equal(true, parser.breakable?(list1_leaf))
    assert_equal(false, parser.breakable?(list2_leaf))
  end

  def test_parse
    text = <<TEXT
!heading1

paragraph1.
paragraph2.
paragraph3.
""citation1
paragraph4.

*list1
*list1-1
**list2
**list2-2
*list3

paragraph5.

!!heading2

paragraph6.
paragraph7.

paragraph8.

!heading3

paragraph9.
TEXT

    tree = PseudoHiki::BlockParser.parse(text.split(/\r?\n/o))
    assert_equal([[[["heading1"]],
                   [[["paragraph1.paragraph2.paragraph3."]]],
                   [[[[["citation1"]]]]],
                   [[["paragraph4."]]],
                   [[[["list1"]]],
                    [[["list1-1"]],
                     [[[["list2"]]],
                      [[["list2-2"]]]]],
                    [[["list3"]]]],
                   [[["paragraph5."]]],
                   [[["heading2"]],
                    [[["paragraph6.paragraph7."]]],
                    [[["paragraph8."]]]]],
                  [[["heading3"]],
                   [[["paragraph9."]]]]],tree)
  end

  def test_parse_with_inline_elements
    text = <<TEXT
!heading

paragraph with a [[link|http://www.example.org/]].

||col||col
:item:description
TEXT

    tree = PseudoHiki::BlockParser.parse(text.split(/\r?\n/o))
    assert_equal([[[["heading"]],
                   [[["paragraph with a "],
                     [["link"],
                      ["|"],
                      ["http"], [":"], ["//www.example.org/"]],
                     ["."]]],
                   [[[["col"]],[["col"]]]],
                   [[["item"], [":"], ["description"]]]]], tree)
  end

  def test_parse_table_with_inline_elements
    text =<<TEXT
||!col||![[link|http://www.example.org/]]||col
TEXT

    parsed_cells = [[[["col"]],
                     [[""],
                     [["link"],
                      ["|"],
                      ["http"], [":"], ["//www.example.org/"]]],
                     [["col"]]]]

    tablenode = PseudoHiki::BlockParser.parse(text.split(/\r?\n/o)).shift
    assert_equal(parsed_cells, tablenode)
    assert_equal(TableNode, tablenode.class)
  end

  def test_assign_node_id
    text = <<TEXT
*[lst]list
TEXT
    list_leaf = ListLeaf.new
    list_leaf.push "[lst]list"
    list_node = ListNode.new
    assert_equal(["[lst]list"], list_leaf)
    PseudoHiki::BlockParser.assign_node_id(list_leaf,list_node)
    assert_equal(["list"], list_leaf)
    assert_equal("lst", list_node.node_id)
    parsed = PseudoHiki::BlockParser.parse(text.split(/\r?\n/o))
    assert_equal([[[[["list"]]]]],parsed)

    text2 = <<TEXT
!!![hd]heading
TEXT

    parsed = PseudoHiki::BlockParser.parse(text2.split(/\r?\n/o))
    assert_equal([[[["heading"]]]],parsed)
  end

  def test_comment_out_followed_by_a_verbatim_block
    text = <<TEXT
the first paragraph

//a comment
<<<
the first verbatim line
the second verbatim line
>>>
TEXT

    parsed = PseudoHiki::BlockParser.parse(text.split(/\r?\n/o))
    assert_equal([[[["the first paragraph"]]], [[["a comment"]]], [[""], ["the first verbatim line"], ["the second verbatim line"]]],parsed)
  end
end
