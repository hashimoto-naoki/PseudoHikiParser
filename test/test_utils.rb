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
end

