#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'
require 'ostruct'

module PseudoHiki
  class PlainTextFormat
    include InlineParser::InlineElement
    include BlockParser::BlockElement

    DescSep = [InlineParser::DescSep]

    Formatters = {}

    class Node < Array
      alias to_s join
    end

    def self.format(tree, options={ :verbose_mode => false })
      if Formatters.empty?
        default_options = { :verbose_mode => false }
        Formatters[default_options] = create(default_options)
      end

      Formatters[options] ||= create(options)
      Formatters[options].format(tree)
    end

    def initialize(formatter={}, options={ :verbose_mode => false })
      @formatter = formatter
      if block_given?
        options_given_via_block = yield
        options.merge!(options_given_via_block)
      end
      @options = OpenStruct.new(options)
    end

    def create_self_element(tree=nil)
      Node.new
    end

    def visited_result(node)
      visitor = @formatter[node.class] || @formatter[PlainNode]
      node.accept(visitor)
    end

    def push_visited_results(element, tree)
      tree.each {|token| element.push visited_result(token) }
    end

    def visit(tree)
      element = create_self_element(tree)
      push_visited_results(element, tree)
      element
    end

    def get_plain
      @formatter[PlainNode]
    end

    def format(tree)
      formatter = get_plain
      tree.accept(formatter).join
    end

    def split_into_parts(tree, separator)
      tree = tree.dup
      first_part = nil
      sep_index = tree.index(separator)
      if sep_index
        first_part = tree.shift(sep_index)
        tree.shift
      end
      return first_part, tree
    end

    def self.create(options={ :verbose_mode => false })
      formatter = {}
      main_formatter = self.new(formatter, options)
      formatter.default = main_formatter

      formatter[InlineLeaf] = InlineLeafFormatter.new(formatter, options)
      formatter[LinkNode] = LinkNodeFormatter.new(formatter, options)
      formatter[DelNode] = DelNodeFormatter.new(formatter, options)
      formatter[DescLeaf] = DescLeafFormatter.new(formatter, options)
      formatter[VerbatimNode] = VerbatimNodeFormatter.new(formatter, options)
      formatter[TableNode] = TableNodeFormatter.new(formatter, options)
      formatter[CommentOutNode] = CommentOutNodeFormatter.new(formatter, options)
      formatter[ParagraphNode] = ParagraphNodeFormatter.new(formatter, options)
      formatter[PluginNode] = PluginNodeFormatter.new(formatter, options)
      main_formatter
    end

## Definitions of subclasses of PlainTextFormat begins here.

    class InlineLeafFormatter < self
      def visit(leaf)
        leaf.join
      end
    end

    class LinkNodeFormatter < self
      def visit(tree)
        element = Node.new
        caption, ref = get_caption(tree)
        if ImageSuffix =~ ref_tail(ref, caption)
          element.push (caption || ref).join
        else
          element.push caption || ref.join
          element.push " (#{ref.join})" if @options.verbose_mode and caption
        end
        element
      end

      def get_caption(tree)
        caption, ref_part = split_into_parts(tree, [LinkSep])
        caption = caption.map {|element| visited_result(element) } if caption
        return caption, ref_part
      end

      def ref_tail(tree, caption)
        tree.last.join
      rescue NoMethodError
        raise NoMethodError unless tree.empty?
        STDERR.puts "No uri is specified for #{caption}"
      end
    end

    class DelNodeFormatter < self
      def visit(tree)
        return "" unless @options.verbose_mode
        "[deleted:#{tree.map {|token| visited_result(token) }.join}]"
      end
    end

    class DescLeafFormatter < self
      def visit(tree)
        element = create_self_element(tree)
        dt_part, dd_part = split_into_parts(tree, DescSep)
        push_visited_results(element, dt_part) if dt_part
        dd = dd_part.map {|token| visited_result(token) }.join.lstrip
        unless dd.empty?
          element.push element.empty? ? "\t" : ":\t"
          element.push dd
        end
        element
      end
    end

    class VerbatimNodeFormatter < self
      def visit(tree)
        tree.join
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
        tree.length.times { table.push create_self_element(tree) }
        max_col = tree.map {|row| row.reduce(0) {|sum, cell| sum + cell.colspan }}.max - 1
        max_row = tree.length - 1
        each_empty_cell_index(max_row, max_col, tree, table) do |r, c, cur_row|
          cur_cell = cur_row.shift
          table[r][c] = visited_result(cur_cell).join.lstrip.chomp
          fill_expand(table, r, c, cur_cell)
        end
        format_table(table, tree)
      end

      def each_empty_cell_index(max_row, max_col, tree, table)
        rows = deep_copy_tree(tree)
        cur_row = nil
        each_cell_index(max_row, max_col) do |r, c|
          cur_row = rows.shift if c == 0
          next if table[r][c]
          if cur_row.empty?
            warning_for_malformed_row(table[r])
          else
            yield r, c, cur_row
          end
        end
      end

      def warning_for_malformed_row(row)
        message = ERROR_MESSAGE%[row.inspect]
        raise MalFormedTableError.new(message) if @options.strict_mode
        STDERR.puts ERROR_MESSAGE%[row.inspect]
      end

      def deep_copy_tree(tree)
        tree.dup.clear.tap do |new_tree|
          new_tree.concat tree.map {|node| node.dup }
        end
      end

      def each_cell_index(max_row, max_col, initial_row=0, initial_col=0)
        initial_row.upto(max_row) do |r|
          initial_col.upto(max_col) do |c|
            yield r, c
          end
        end
      end

      def fill_expand(table, initial_row, initial_col, cur_cell)
        row_expand, col_expand = choose_expander_of_col_and_row
        max_row = initial_row + cur_cell.rowspan - 1
        max_col = initial_col + cur_cell.colspan - 1
        each_cell_index(max_row, max_col,
                        initial_row, initial_col) do |r, c|
          unless initial_row == r and initial_col == c
            table[r][c] = initial_row == r ? col_expand : row_expand
          end
        end
      end
    end

    def choose_expander_of_col_and_row
      @options.verbose_mode ? ["||", "=="] : ["", ""]
    end

    def format_table(table, tree)
      table.map {|row| row.join("\t") + $/ }.join
    end

    class CommentOutNodeFormatter < self
      def visit(tree); ""; end
    end

    class ParagraphNodeFormatter < self
      def visit(tree)
        super(tree).join + $/
      end
    end

    class PluginNodeFormatter < self
      def visit(tree)
        str = tree.join
        return str.strip * 2 if str == " {" or str == "} "
        super(tree)
      end
    end
  end
end
