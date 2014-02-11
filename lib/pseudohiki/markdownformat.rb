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

    def list_mark(tree, mark)
      mark = mark.dup
      mark << " " if /^ /o !~ tree.join
      " " * (tree.nominal_level - 1) * 2 + mark
    end

    def enclose_in(element, mark)
      element.push mark
      element.unshift mark
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
#       DelNode,
       PluginNode,
       DescLeaf,
       TableCellNode,
#       VerbatimLeaf,
       QuoteLeaf,
       TableLeaf,
#       CommentOutLeaf,
#       HeadingLeaf,
       ParagraphLeaf,
#       HrLeaf,
       BlockNodeEnd,
       ListLeaf,
       EnumLeaf,
       DescNode,
#       VerbatimNode,
#       QuoteNode,
#       TableNode,
       CommentOutNode,
#       HeadingNode,
#       ParagraphNode,
       HrNode,
       ListNode,
       EnumNode,
#       ListWrapNode,
#       EnumWrapNode
      ].each do |node_class|
        formatter[node_class] = self.new(formatter, options)
      end

#      formatter[PlainNode] = PlainNodeFormatter.new(formatter, options)
#      formatter[InlineNode] = InlineNodeFormatter.new(formatter, options)
      formatter[InlineLeaf] = InlineLeafFormatter.new(formatter, options)
      formatter[LinkNode] = LinkNodeFormatter.new(formatter, options)
      formatter[EmNode] = EmNodeFormatter.new(formatter, options)
      formatter[StrongNode] = StrongNodeFormatter.new(formatter, options)
      formatter[DelNode] = DelNodeFormatter.new(formatter, options)
#      formatter[PluginNode] = PluginNodeFormatter.new(formatter, options)
#      formatter[DescLeaf] = DescLeafFormatter.new(formatter, options)
#      formatter[TableCellNode] = TableCellNodeFormatter.new(formatter, options)
      formatter[VerbatimLeaf] = VerbatimLeafFormatter.new(formatter, options)
#      formatter[QuoteLeaf] = QuoteLeafFormatter.new(formatter, options)
#      formatter[TableLeaf] = TableLeafFormatter.new(formatter, options)
      formatter[CommentOutLeaf] = CommentOutLeafFormatter.new(formatter, options)
      formatter[HeadingLeaf] = HeadingLeafFormatter.new(formatter, options)
#      formatter[ParagraphLeaf] = ParagraphLeafFormatter.new(formatter, options)
      formatter[HrLeaf] = HrLeafFormatter.new(formatter, options)
#      formatter[BlockNodeEnd] = BlockNodeEndFormatter.new(formatter, options)
#      formatter[ListLeaf] = ListLeafFormatter.new(formatter, options)
#      formatter[EnumLeaf] = EnumLeafFormatter.new(formatter, options)
#      formatter[DescNode] = DescNodeFormatter.new(formatter, options)
      formatter[VerbatimNode] = VerbatimNodeFormatter.new(formatter, options)
      formatter[QuoteNode] = QuoteNodeFormatter.new(formatter, options)
      formatter[TableNode] = TableNodeFormatter.new(formatter, options)
#      formatter[CommentOutNode] = CommentOutNodeFormatter.new(formatter, options)
      formatter[HeadingNode] = HeadingNodeFormatter.new(formatter, options)
      formatter[ParagraphNode] = ParagraphNodeFormatter.new(formatter, options)
#      formatter[HrNode] = HrNodeFormatter.new(formatter, options)
#      formatter[ListNode] = ListNodeFormatter.new(formatter, options)
#      formatter[EnumNode] = EnumNodeFormatter.new(formatter, options)
      formatter[ListWrapNode] = ListWrapNodeFormatter.new(formatter, options)
      formatter[EnumWrapNode] = EnumWrapNodeFormatter.new(formatter, options)

      main_formatter
    end

## Definitions of subclasses of MarkDownFormat begins here.

#    class PlainNodeFormatter < self; end
#    class InlineNodeFormatter < self; end

    class InlineLeafFormatter < self
      def visit(leaf)
        leaf.map {|str| str.gsub(/([_*])/o, "\\\\\\1") }
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
          enclose_in(element, "_")
        end
      end
    end

    class StrongNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          enclose_in(element, "**")
        end
      end
    end

    class DelNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          enclose_in(element, "~~")
        end
      end
    end

#    class PluginNodeFormatter < self; end
#    class DescLeafFormatter < self; end
#    class TableCellNodeFormatter < self; end

    class VerbatimLeafFormatter < InlineLeafFormatter; end

#    class QuoteLeafFormatter < self; end
#    class TableLeafFormatter < self; end

    class CommentOutLeafFormatter < self
      def visit(tree); ""; end
    end

    class HeadingLeafFormatter < self
      def visit(tree)
        super(tree).tap {|element| element.push $/ }
      end
    end
#    class ParagraphLeafFormatter < self; end

    class HrLeafFormatter < self
      def visit(tree)
        "----#{$/}"
      end
    end

#    class BlockNodeEndFormatter < self; end
#    class ListLeafFormatter < self; end
#    class EnumLeafFormatter < self; end
#    class DescNodeFormatter < self; end

    class VerbatimNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          element.unshift "#{$/}```#{$/}"
          element.push "```#{$/ * 2}"
        end
      end
    end

    class QuoteNodeFormatter < self
      def visit(tree)
        element = super(tree)
        element.join.gsub(/^/o, "> ").sub(/> \Z/o, "")
      end
    end

    class TableNodeFormatter < self
      class MalFormedTableError < StandardError; end
      ERROR_MESSAGE = <<ERROR_TEXT
!! A malformed row is found: %s.
!! Please recheck if it is really what you want.
ERROR_TEXT

      def visit(tree)
        table = create_self_element(tree)
        rows = tree.dup
        header_height = 0
        rows.each {|row| header_height += 1 if row.first.cell_type == "th" }
        rows.length.times { table.push create_self_element(tree) }
        max_col = tree.map{|row| row.reduce(0) {|sum, cell| sum + cell.colspan }}.max - 1
        max_row = rows.length - 1
        cur_row = nil
        each_cell_with_index(table, max_row, max_col) do |cell, r, c|
          cur_row = rows.shift if c == 0
          next if table[r][c]
          unless cell
            begin
              raise MalFormedTableError.new(ERROR_MESSAGE%[table[r].inspect]) if cur_row.empty?
              table[r][c] = cur_row.shift
              fill_expand(table, r, c, table[r][c])
            rescue
              STDERR.puts ERROR_MESSAGE%[table[r].inspect]
              next
            end
          end
        end

        STDERR.puts "The header row is missing. The first row will be treated as a header." if header_height == 0
        format_table(table)
      end

      def each_cell_with_index(table, max_row, max_col, initial_row=0, initial_col=0)
        initial_row.upto(max_row) do |r|
          initial_col.upto(max_col) do |c|
            yield table[r][c], r, c
          end
        end
      end

      def fill_expand(table, initial_row, initial_col, cur_cell)
        row_expand, col_expand = "", ""
        max_row = initial_row + cur_cell.rowspan - 1
        max_col = initial_col + cur_cell.colspan - 1
        each_cell_with_index(table, max_row, max_col,
                             initial_row, initial_col) do |cell, r, c|
          if initial_row == r and initial_col == c
            table[r][c] = visited_result(cur_cell).join.lstrip.chomp
            next
          end
          table[r][c] = initial_row == r ? col_expand : row_expand
        end
      end

      def format_table(table)
        cell_width = calculate_cell_width(table)
        header_delimiter = cell_width.map {|width| "-" * width }
        cell_formats = cell_width.map {|width| "%-#{width}s" }
        table[1,0] = [header_delimiter]
        table.map do |row|
          formatted_row = row.zip(cell_formats).map do |cell, format|
            format%[cell]
          end
          "|#{formatted_row.join("|") }|#{$/}"
        end.join
      end

      def calculate_cell_width(table)
        cell_width = Array.new(table.first.length, 0)
        table.each do |row|
          row.each_with_index do |cell, i|
            cell_width[i] = cell.length if cell_width[i] < cell.length
          end
        end
        cell_width
      end
    end

#    class CommentOutNodeFormatter < self; end

    class HeadingNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          heading_mark = "#" * tree.first.nominal_level
          heading_mark << " " if /^ /o !~ tree.join
          element.unshift heading_mark
        end
      end
    end

    class ParagraphNodeFormatter < self
      def visit(tree)
        super(tree).tap {|element| element.push $/ }
      end
    end

#    class HrNodeFormatter < self; end
#    class ListNodeFormatter < self; end
#    class EnumNodeFormatter < self; end

    class ListWrapNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          element.unshift list_mark(tree, "*")
        end
      end
    end

    class EnumWrapNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          element.unshift list_mark(tree, "#{tree.nominal_level}.")
        end
      end
    end
  end
end
