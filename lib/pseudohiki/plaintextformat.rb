#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'

module PseudoHiki
  class PlainTextFormat
    include InlineParser::InlineElement
    include BlockParser::BlockElement

    class Node < Array

      def to_s
        self.join
      end
    end

    Formatter = {}

    def create_self_element(tree=nil)
      Node.new
    end

    def visited_result(node)
      visitor = Formatter[node.class]||Formatter[PlainNode]
      node.accept(visitor)
    end

    def visit(tree)
      element = create_self_element(tree)
      tree.each do |node|
        element.push visited_result(node)
      end
      element
    end

## Definitions of subclasses of PlainTextFormat begins here.

    class PlainNodeFormatter < self; end
    Formatter[PlainNode] = PlainNodeFormatter.new

    class InlineNodeFormatter < self; end
    Formatter[InlineNode] = InlineNodeFormatter.new

    class InlineLeafFormatter < self
      def visit(leaf)
        leaf.join
      end
    end
    Formatter[InlineLeaf] = InlineLeafFormatter.new

    class LinkNodeFormatter < self
      def visit(tree)
        tree = tree.dup
        element = Node.new
        caption = nil
        link_sep_index = tree.find_index([LinkSep])
        if link_sep_index
          caption = get_caption(tree,link_sep_index)
          tree.shift(link_sep_index+1)
        end
        begin
          ref = tree.last.join("")
        rescue NoMethodError
          if tree.empty?
            STDERR.puts "No uri is specified for #{caption}"
          else
            raise NoMethodError
          end
        end
        if ImageSuffix =~ ref
          element.push (caption||tree).join("")
        else
          element.push caption||tree.join("")
        end
        element
      end

      def get_caption(tree,link_sep_index)
        tree[0,link_sep_index].collect do |element|
          visited_result(element)
        end
      end
    end
    Formatter[LinkNode] = LinkNodeFormatter.new

    class EmNodeFormatter < self; end
    Formatter[EmNode] = EmNodeFormatter.new

    class StrongNodeFormatter < self; end
    Formatter[StrongNode] = StrongNodeFormatter.new

    class DelNodeFormatter < self; end
    Formatter[DelNode] = DelNodeFormatter.new

    class PluginNodeFormatter < self; end
    Formatter[PluginNode] = PluginNodeFormatter.new

    class DescLeafFormatter < self; end
    Formatter[DescLeaf] = DescLeafFormatter.new

    class VerbatimLeafFormatter < self; end
    Formatter[VerbatimLeaf] = VerbatimLeafFormatter.new

    class QuoteLeafFormatter < self; end
    Formatter[QuoteLeaf] = QuoteLeafFormatter.new

    class TableLeafFormatter < self; end
    Formatter[TableLeaf] = TableLeafFormatter.new

    class CommentOutLeafFormatter < self; end
    Formatter[CommentOutLeaf] = CommentOutLeafFormatter.new

    class HeadingLeafFormatter < self; end
    Formatter[HeadingLeaf] = HeadingLeafFormatter.new

    class ParagraphLeafFormatter < self; end
    Formatter[ParagraphLeaf] = ParagraphLeafFormatter.new

    class HrLeafFormatter < self; end
    Formatter[HrLeaf] = HrLeafFormatter.new

    class BlockNodeEndFormatter < self; end
    Formatter[BlockNodeEnd] = BlockNodeEndFormatter.new

    class ListLeafFormatter < self; end
    Formatter[ListLeaf] = ListLeafFormatter.new

    class EnumLeafFormatter < self; end
    Formatter[EnumLeaf] = EnumLeafFormatter.new

    class DescNodeFormatter < self; end
    Formatter[DescNode] = DescNodeFormatter.new

    class VerbatimNodeFormatter < self; end
    Formatter[VerbatimNode] = VerbatimNodeFormatter.new

    class QuoteNodeFormatter < self; end
    Formatter[QuoteNode] = QuoteNodeFormatter.new

    class TableNodeFormatter < self; end
    Formatter[TableNode] = TableNodeFormatter.new

    class CommentOutNodeFormatter < self
      def visit(tree); ""; end
    end
    Formatter[CommentOutNode] = CommentOutNodeFormatter.new

    class HeadingNodeFormatter < self; end
    Formatter[HeadingNode] = HeadingNodeFormatter.new

    class ParagraphNodeFormatter < self; end
    Formatter[ParagraphNode] = ParagraphNodeFormatter.new

    class HrNodeFormatter < self; end
    Formatter[HrNode] = HrNodeFormatter.new

    class ListNodeFormatter < self; end
    Formatter[ListNode] = ListNodeFormatter.new

    class EnumNodeFormatter < self; end
    Formatter[EnumNode] = EnumNodeFormatter.new

    class ListWrapNodeFormatter < self; end
    Formatter[ListWrapNode] = ListWrapNodeFormatter.new

    class EnumWrapNodeFormatter < self; end
    Formatter[EnumWrapNode] = EnumWrapNodeFormatter.new


    def self.get_plain
      self::Formatter[PlainNode]
    end
    
    def self.format(tree)
      formatter = self.get_plain
      tree.accept(formatter)
    end
  end
end
