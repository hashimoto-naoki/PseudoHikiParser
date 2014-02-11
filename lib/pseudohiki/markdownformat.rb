#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'
require 'htmlelement'

module PseudoHiki
  class MarkDownFormat
    include InlineParser::InlineElement
    include TableRowParser::InlineElement
    include BlockParser::BlockElement

    def initialize(formatter={}, options=nil)
      @formatter = formatter
      @options = options
    end

    def create_self_element(tree=nil)
      HtmlElement::Children.new
    end

    def visited_result(node)
      visitor = @formatter[node.class]||@formatter[PlainNode]
      node.accept(visitor)
    end

    def visit(tree)
      element = create_self_element(tree)
      tree.each do |node|
        element.push visited_result(node)
      end
      element
    end

    def get_plain
      @formatter[PlainNode]
    end
    
    def format(tree)
      formatter = self.get_plain
      tree.accept(formatter)
    end

    def self.create(options=nil)
      formatter = {}

      main_formatter = self.new(formatter, options)

      [
       PlainNode,
       InlineNode,
#       InlineLeaf,
#       LinkNode,
#       EmNode,
#       StrongNode,
       DelNode,
       PluginNode,
       DescLeaf,
       TableCellNode,
       VerbatimLeaf,
       QuoteLeaf,
       TableLeaf,
       CommentOutLeaf,
       HeadingLeaf,
       ParagraphLeaf,
       HrLeaf,
       BlockNodeEnd,
       ListLeaf,
       EnumLeaf,
       DescNode,
       VerbatimNode,
       QuoteNode,
       TableNode,
       CommentOutNode,
#       HeadingNode,
       ParagraphNode,
       HrNode,
       ListNode,
       EnumNode,
       ListWrapNode,
       EnumWrapNode
      ].each do |node_class|
        formatter[node_class] = self.new(formatter, options)
      end

#      @formatter[PlainNode] = PlainNodeFormatter.new(formatter, options)
#      @formatter[InlineNode] = InlineNodeFormatter.new(formatter, options)
      formatter[InlineLeaf] = InlineLeafFormatter.new(formatter, options)
      formatter[LinkNode] = LinkNodeFormatter.new(formatter, options)
      formatter[EmNode] = EmNodeFormatter.new(formatter, options)
      formatter[StrongNode] = StrongNodeFormatter.new(formatter, options)
#      formatter[DelNode] = DelNodeFormatter.new(formatter, options)
#      formatter[PluginNode] = PluginNodeFormatter.new(formatter, options)
#      formatter[DescLeaf] = DescLeafFormatter.new(formatter, options)
#      formatter[TableCellNode] = TableCellNodeFormatter.new(formatter, options)
#      formatter[VerbatimLeaf] = VerbatimLeafFormatter.new(formatter, options)
#      formatter[QuoteLeaf] = QuoteLeafFormatter.new(formatter, options)
#      formatter[TableLeaf] = TableLeafFormatter.new(formatter, options)
#      formatter[CommentOutLeaf] = CommentOutLeafFormatter.new(formatter, options)
#      formatter[HeadingLeaf] = HeadingLeafFormatter.new(formatter, options)
#      formatter[ParagraphLeaf] = ParagraphLeafFormatter.new(formatter, options)
#      formatter[HrLeaf] = HrLeafFormatter.new(formatter, options)
#      formatter[BlockNodeEnd] = BlockNodeEndFormatter.new(formatter, options)
#      formatter[ListLeaf] = ListLeafFormatter.new(formatter, options)
#      formatter[EnumLeaf] = EnumLeafFormatter.new(formatter, options)
#      formatter[DescNode] = DescNodeFormatter.new(formatter, options)
#      formatter[VerbatimNode] = VerbatimNodeFormatter.new(formatter, options)
#      formatter[QuoteNode] = QuoteNodeFormatter.new(formatter, options)
#      formatter[TableNode] = TableNodeFormatter.new(formatter, options)
#      formatter[CommentOutNode] = CommentOutNodeFormatter.new(formatter, options)
      formatter[HeadingNode] = HeadingNodeFormatter.new(formatter, options)
#      formatter[ParagraphNode] = ParagraphNodeFormatter.new(formatter, options)
#      formatter[HrNode] = HrNodeFormatter.new(formatter, options)
#      formatter[ListNode] = ListNodeFormatter.new(formatter, options)
#      formatter[EnumNode] = EnumNodeFormatter.new(formatter, options)
#      formatter[ListWrapNode] = ListWrapNodeFormatter.new(formatter, options)
#      formatter[EnumWrapNode] = EnumWrapNodeFormatter.new(formatter, options)

      main_formatter
    end

## Definitions of subclasses of MarkDownFormat begins here.

#    class PlainNodeFormatter < self; end
#    class InlineNodeFormatter < self; end
    class InlineLeafFormatter < self
      def visit(leaf)
        leaf.join
      end
    end

    class LinkNodeFormatter < self
      def visit(tree)
        tree = tree.dup
        element = create_self_element
        caption = get_caption(tree)
        begin
          ref = tree.last.join
        rescue NoMethodError
          raise NoMethodError unless tree.empty?
          STDERR.puts "No uri is specified for #{caption}"
        end
        element.push "!" if ImageSuffix =~ ref
        element.push "[#{(caption||tree).join}](#{tree.join})"
        element
      end

      def get_caption(tree)
        link_sep_index = tree.find_index([LinkSep])
        return nil unless link_sep_index
        caption_part = tree.shift(link_sep_index)
        tree.shift
        caption_part.map {|element| visited_result(element) }
      end
    end

    class EmNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          element.unshift "_"
          element.push "_"
        end
      end
    end

    class StrongNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          element.unshift "**"
          element.push "**"
        end
      end
    end
#    class DelNodeFormatter < self; end
#    class PluginNodeFormatter < self; end
#    class DescLeafFormatter < self; end
#    class TableCellNodeFormatter < self; end
#    class VerbatimLeafFormatter < self; end
#    class QuoteLeafFormatter < self; end
#    class TableLeafFormatter < self; end
#    class CommentOutLeafFormatter < self; end
#    class HeadingLeafFormatter < self; end
#    class ParagraphLeafFormatter < self; end
#    class HrLeafFormatter < self; end
#    class BlockNodeEndFormatter < self; end
#    class ListLeafFormatter < self; end
#    class EnumLeafFormatter < self; end
#    class DescNodeFormatter < self; end
#    class VerbatimNodeFormatter < self; end
#    class QuoteNodeFormatter < self; end
#    class TableNodeFormatter < self; end
#    class CommentOutNodeFormatter < self; end
    class HeadingNodeFormatter < self
      def visit(tree)
        heading_level = tree.first.nominal_level
        element = create_self_element(tree)
        element.push "#"*heading_level + " "
        tree.each do |node|
          element.push visited_result(node)
        end
        element
      end
    end
#    class ParagraphNodeFormatter < self; end
#    class HrNodeFormatter < self; end
#    class ListNodeFormatter < self; end
#    class EnumNodeFormatter < self; end
#    class ListWrapNodeFormatter < self; end
#    class EnumWrapNodeFormatter < self; end

  end
end
