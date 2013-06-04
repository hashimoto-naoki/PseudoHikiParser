#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'

module PseudoHiki
  class PlainTextFormat
    include InlineParser::InlineElement
    include BlockParser::BlockElement

    TableSep = [InlineParser::TableSep]
    DescSep = [InlineParser::DescSep]

    class Node < Array

      def to_s
        self.join("")
      end
    end

    class TableCell < Node
      attr_accessor :rowspan, :colspan

      def initialize
        super
        @rowspan = 1
        @colspan = 1
      end
    end

    def create_self_element(tree=nil)
      Node.new
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

#    def []=(node_class, formatter_instance)
#      @formatter[node_class] = formatter_instance
#    end

    def initialize(formatter={}, verbose_mode=false)
      @formatter = formatter
      @verbose_mode = verbose_mode
    end

    def self.create(verbose_mode=false)
      formatter = {}
      main = self.new(formatter, verbose_mode)
      formatter[PlainNode] = PlainNodeFormatter.new(formatter, verbose_mode)
      formatter[InlineNode] = InlineNodeFormatter.new(formatter, verbose_mode)
      formatter[InlineLeaf] = InlineLeafFormatter.new(formatter, verbose_mode)
      formatter[LinkNode] = LinkNodeFormatter.new(formatter, verbose_mode)
      formatter[EmNode] = EmNodeFormatter.new(formatter, verbose_mode)
      formatter[StrongNode] = StrongNodeFormatter.new(formatter, verbose_mode)
      formatter[DelNode] = DelNodeFormatter.new(formatter, verbose_mode)
      formatter[PluginNode] = PluginNodeFormatter.new(formatter, verbose_mode)
      formatter[DescLeaf] = DescLeafFormatter.new(formatter, verbose_mode)
      formatter[VerbatimLeaf] = VerbatimLeafFormatter.new(formatter, verbose_mode)
      formatter[QuoteLeaf] = QuoteLeafFormatter.new(formatter, verbose_mode)
      formatter[TableLeaf] = TableLeafFormatter.new(formatter, verbose_mode)
      formatter[CommentOutLeaf] = CommentOutLeafFormatter.new(formatter, verbose_mode)
      formatter[ParagraphLeaf] = ParagraphLeafFormatter.new(formatter, verbose_mode)
      formatter[HeadingLeaf] = HeadingLeafFormatter.new(formatter, verbose_mode)
      formatter[HrLeaf] = HrLeafFormatter.new(formatter, verbose_mode)
      formatter[BlockNodeEnd] = BlockNodeEndFormatter.new(formatter, verbose_mode)
      formatter[ListLeaf] = ListLeafFormatter.new(formatter, verbose_mode)
      formatter[EnumLeaf] = EnumLeafFormatter.new(formatter, verbose_mode)
      formatter[DescNode] = DescNodeFormatter.new(formatter, verbose_mode)
      formatter[VerbatimNode] = VerbatimNodeFormatter.new(formatter, verbose_mode)
      formatter[QuoteNode] = QuoteNodeFormatter.new(formatter, verbose_mode)
      formatter[TableNode] = TableNodeFormatter.new(formatter, verbose_mode)
      formatter[CommentOutNode] = CommentOutNodeFormatter.new(formatter, verbose_mode)
      formatter[HeadingNode] = HeadingNodeFormatter.new(formatter, verbose_mode)
      formatter[ParagraphNode] = ParagraphNodeFormatter.new(formatter, verbose_mode)
      formatter[HrNode] = HrNodeFormatter.new(formatter, verbose_mode)
      formatter[ListNode] = ListNodeFormatter.new(formatter, verbose_mode)
      formatter[EnumNode] = EnumNodeFormatter.new(formatter, verbose_mode)
      formatter[ListWrapNode] = ListWrapNodeFormatter.new(formatter, verbose_mode)
      formatter[EnumWrapNode] = EnumWrapNodeFormatter.new(formatter, verbose_mode)
      main
    end

    def get_plain
      @formatter[PlainNode]
    end

    def format(tree)
      formatter = get_plain
      tree.accept(formatter)
    end

## Definitions of subclasses of PlainTextFormat begins here.

    class PlainNodeFormatter < self; end

    class InlineNodeFormatter < self; end

    class InlineLeafFormatter < self
      def visit(leaf)
        leaf.join("")
      end
    end

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
          element.push " (#{tree.join('')})" if @verbose_mode and caption
        end
        element
      end

      def get_caption(tree,link_sep_index)
        tree[0,link_sep_index].collect do |element|
          visited_result(element)
        end
      end
    end

    class EmNodeFormatter < self; end
    class StrongNodeFormatter < self; end
    class DelNodeFormatter < self; end
    class PluginNodeFormatter < self; end

    class DescLeafFormatter < self
      def visit(tree)
        tree = tree.dup
        element = create_self_element(tree)
        dt_sep_index = tree.index(DescSep)
        if dt_sep_index
          tree.shift(dt_sep_index).each do |token|
            element.push visited_result(token)
          end
          tree.shift
        end
        dd = tree.map {|token| visited_result(token) }.join("").lstrip
        unless dd.empty?
          element.push element.empty? ? "\t" : ":\t"
          element.push dd
        end
        element
      end
    end

    class VerbatimLeafFormatter < self; end
    class QuoteLeafFormatter < self; end

    class TableLeafFormatter < self
      TD, TH, ROW_EXPANDER, COL_EXPANDER, TH_PAT = %w(td th ^ > !)
      MODIFIED_CELL_PAT = /^!?[>^]*/o

      def parse_first_token(token)
        parsed_token, cell_type, rowspan, colspan = token, TD, nil, nil
        m, cell_modifiers = nil, nil
        m = MODIFIED_CELL_PAT.match(token) if token.kind_of? String
        if m
          cell_modifiers = m[0].split(//o)
          if cell_modifiers.first == TH_PAT
            cell_modifiers.shift
            cell_type = TH
          end
          parsed_token = token.sub(MODIFIED_CELL_PAT,"").lstrip
          row_width = cell_modifiers.count(ROW_EXPANDER) + 1
          rowspan = row_width if row_width > 1
          col_width = cell_modifiers.count(COL_EXPANDER) + 1
          colspan = col_width if col_width > 1
        end
        [parsed_token, cell_type, rowspan, colspan]
      end

      def visit(tree)
        row = create_self_element(tree)
        cells = tree.dup
        cells.push TableSep
        while i = cells.index(TableSep)
          first_cell = cells.shift.dup
          first_cell[0], cell_type, rowspan, colspan = parse_first_token(first_cell[0])
          col = TableCell.new
          col.push visited_result(first_cell)
          row.push col
          col.rowspan = rowspan if rowspan
          col.colspan = colspan if colspan

          (i-1).times do
            cell = cells.shift
            col.push visited_result(cell)
          end
          cells.shift
        end
        row
      end
    end

    class CommentOutLeafFormatter < self; end
    class HeadingLeafFormatter < self; end
    class ParagraphLeafFormatter < self; end
    class HrLeafFormatter < self; end
    class BlockNodeEndFormatter < self; end
    class ListLeafFormatter < self; end
    class EnumLeafFormatter < self; end
    class DescNodeFormatter < self; end

    class VerbatimNodeFormatter < self
      def visit(tree)
        tree.join("")
      end
    end

    class QuoteNodeFormatter < self; end

    class TableNodeFormatter < self
      def visit(tree)
        table = create_self_element(tree)
        rows = tree.map {|row| visited_result(row) }
        rows.length.times { table.push Node.new }
        max_col = rows.map{|row| row.reduce(0) {|sum, cell| sum + cell.colspan }}.max - 1
        max_row = rows.length - 1
        cur_row = nil
        each_cell_with_index(table, max_row, max_col) do |cell, r, c|
          cur_row = rows.shift if c == 0
          next if table[r][c]
          if cell.nil?
            table[r][c] = cur_row.shift
            fill_expand(table, r, c, table[r][c])
          end
        end
        table.map {|row| row.join("\t") }.join("")
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
        row_expand, col_expand = "||", "==" if @verbose_mode
        max_row = initial_row + cur_cell.rowspan - 1
        max_col = initial_col + cur_cell.colspan - 1
        each_cell_with_index(table, max_row, max_col,
                             initial_row, initial_col) do |cell, r, c|
          next if initial_row == r and initial_col == c
          if initial_row == r
            table[r][c] = col_expand
          else
            table[r][c] = row_expand
          end
        end
      end
    end

    class CommentOutNodeFormatter < self
      def visit(tree); ""; end
    end

    class HeadingNodeFormatter < self; end
    class ParagraphNodeFormatter < self; end
    class HrNodeFormatter < self; end
    class ListNodeFormatter < self; end
    class EnumNodeFormatter < self; end
    class ListWrapNodeFormatter < self; end
    class EnumWrapNodeFormatter < self; end
  end
end
