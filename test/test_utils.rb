#!/usr/bin/env ruby

require 'minitest/autorun'
require 'pseudohikiparser'
require 'pseudohiki/utils'

class TC_NodeCollector < MiniTest::Unit::TestCase

  def setup
    @input_text = <<TEXT
!Title

!![heading1]Heading1

paragaraph

!!Heading2

paragragh

!![heading3]Heading3

paragraph
TEXT
  end

  def test_nodecollector
    tree = PseudoHiki::BlockParser.parse(@input_text)
    nodes = PseudoHiki::Utils::NodeCollector.select(tree) do |node|
      node.kind_of?(PseudoHiki::BlockParser::HeadingLeaf) and
        node.level == 2 and
        node.node_id
    end

    selected_headings = [[["Heading1\n"]],
                [["Heading3\n"]]]

    assert_equal(selected_headings, nodes)
  end

  def test_table_manager_determine_header_scope
    table_with_row_header_text = <<TABLE
||!header1||!header2||!header3
||row1-1||row1-2||row1-3
||row2-1||row2-2||row2-3
TABLE

table_with_col_header_text = <<TABLE
||!header1||col1-1||col2-1
||!header2||col1-2||col2-2
||!header3||col1-3||col2-3
TABLE

    table_manager = PseudoHiki::Utils::TableManager.new

    table_with_row_header = PseudoHiki::BlockParser.parse(table_with_row_header_text)[0]
    assert_equal("col", table_manager.determine_header_scope(table_with_row_header))

    table_with_col_header = PseudoHiki::BlockParser.parse(table_with_col_header_text)[0]
    assert_equal("row", table_manager.determine_header_scope(table_with_col_header))
  end
end

