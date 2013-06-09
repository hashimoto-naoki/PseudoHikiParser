#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'
require 'ostruct'

module PseudoHiki
  class PlainTextFormat
    include InlineParser::InlineElement
    include BlockParser::BlockElement

    DescSep = [InlineParser::DescSep]

    class Node < Array

      def to_s
        self.join("")
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

    def initialize(formatter={}, options = { :verbose_mode=> false })
      @formatter = formatter
      options_given_via_block = nil
      if block_given?
        options_given_via_block = yield
        options.merge!(options_given_via_block)
      end
      @options = OpenStruct.new(options)
    end

    def self.create(options = { :verbose_mode => false })
      formatter = {}
      main = self.new(formatter, options)

      [
       PlainNode,
       InlineNode,
       EmNode,
       StrongNode,
       PluginNode,
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
       QuoteNode,
       HeadingNode,
       HrNode,
       ListNode,
       EnumNode,
       ListWrapNode,
       EnumWrapNode
      ].each do |node_class|
        formatter[node_class] = self.new(formatter, options)
      end

      formatter[InlineLeaf] = InlineLeafFormatter.new(formatter, options)
      formatter[LinkNode] = LinkNodeFormatter.new(formatter, options)
      formatter[DelNode] = DelNodeFormatter.new(formatter, options)
      formatter[DescLeaf] = DescLeafFormatter.new(formatter, options)
      formatter[VerbatimNode] = VerbatimNodeFormatter.new(formatter, options)
      formatter[TableNode] = TableNodeFormatter.new(formatter, options)
      formatter[CommentOutNode] = CommentOutNodeFormatter.new(formatter, options)
      formatter[ParagraphNode] = ParagraphNodeFormatter.new(formatter, options)
      main
    end

    def get_plain
      @formatter[PlainNode]
    end

    def format(tree)
      formatter = get_plain
      tree.accept(formatter).join("")
    end

## Definitions of subclasses of PlainTextFormat begins here.

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
          element.push " (#{tree.join('')})" if @options.verbose_mode and caption
        end
        element
      end

      def get_caption(tree,link_sep_index)
        tree[0,link_sep_index].collect do |element|
          visited_result(element)
        end
      end
    end

    class DelNodeFormatter < self; end

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

    class VerbatimNodeFormatter < self
      def visit(tree)
        tree.join("")
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
        rows.length.times { table.push Node.new }
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
              raise if @options.strict_mode
              STDERR.puts ERROR_MESSAGE%[table[r].inspect]
              next
            end
          end
        end
        table.map {|row| row.join("\t")+$/ }.join("")
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
        row_expand, col_expand = "||", "==" if @options.verbose_mode
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
    end

    class CommentOutNodeFormatter < self
      def visit(tree); ""; end
    end

    class ParagraphNodeFormatter < self
      def visit(tree)
        super(tree).join+$/
      end
    end
  end
end
