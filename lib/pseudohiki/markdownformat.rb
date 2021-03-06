#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'
require 'pseudohiki/htmlformat'
require 'pseudohiki/plaintextformat'
require 'pseudohiki/utils'
require 'htmlelement'
require 'ostruct'

module PseudoHiki
  class MarkDownFormat
    include InlineParser::InlineElement
    include TableRowParser::InlineElement
    include BlockParser::BlockElement

    Formatters = {}
    GFM_STRIPPED_CHARS = " -&+$,/:;=?@\"{}#|^~[]`\\*()%.!'"
    GFM_STRIPPED_CHARS_PAT = Regexp.union(/\s+/o, /[#{Regexp.escape(GFM_STRIPPED_CHARS)}]/o)

    @default_options = { :strict_mode => false, :gfm_style => false }

    def self.default_options
      @default_options
    end

    def self.format(tree, options=MarkDownFormat.default_options)
      if Formatters.empty?
        default_options = MarkDownFormat.default_options
        Formatters[default_options] = create(default_options)
      end

      Formatters[options] ||= create(options)
      Formatters[options].format(tree)
    end

    def self.convert_into_gfm_id_format(heading)
      heading.gsub(GFM_STRIPPED_CHARS_PAT) do |char|
        /\A\s+\Z/o.match?(char) ? '-'.freeze : ''.freeze
      end.downcase
    end

    def initialize(formatter={}, options=MarkDownFormat.default_options)
      @formatter = formatter
      if block_given?
        options_given_via_block = yield
        options.merge!(options_given_via_block)
      end
      @options = OpenStruct.new(options)
    end

    def create_self_element(tree=nil)
      HtmlElement::Children.new
    end

    def visited_result(node, memo)
      visitor = @formatter[node.class] || @formatter[PlainNode]
      node.accept(visitor, memo)
    end

    def push_visited_results(element, tree, memo)
      tree.each {|token| element.push visited_result(token, memo) }
    end

    def visit(tree, memo)
      element = create_self_element(tree)
      push_visited_results(element, tree, memo)
      element.tap {|elm| tap_element_in_visit(elm, tree, memo) }
    end

    def tap_element_in_visit(elm, tree, memo); end

    def get_plain
      @formatter[PlainNode]
    end

    def format(tree)
      formatter = get_plain
      prepare_id_conv_table(tree) if @options.gfm_style
      tree.accept(formatter).join
    end

    def list_mark(tree, mark)
      mark = mark.dup
      mark << " " unless /^ /o.match? tree.join
      " " * (tree.level - 1) * 2 + mark
    end

    def enclose_in(element, mark)
      element.push mark
      element.unshift mark
    end

    def remove_trailing_newlines_in_html_element(element)
      element.to_s.gsub(/([^>])\r?\n/, "\\1") << $/
    end

    def collect_headings(tree)
      PseudoHiki::Utils::NodeCollector.select(tree) do |node|
        node.kind_of? PseudoHiki::BlockParser::HeadingLeaf
      end
    end

    def heading_to_gfm_id(heading)
      heading_text = PlainTextFormat.format(heading).strip
      MarkDownFormat.convert_into_gfm_id_format(heading_text)
    end

    def prepare_id_conv_table(tree)
      {}.tap do |table|
        collect_headings(tree).each do |heading|
          if node_id = heading.node_id
            table[node_id] = heading_to_gfm_id(heading)
          end
        end
        @formatter[LinkNode].id_conv_table = table
      end
    end

    def self.create(options={ :strict_mode => false })
      formatter = {}

      new(formatter, options).tap do |main_formatter|
        formatter.default = main_formatter

        [[InlineLeaf, InlineLeafFormatter],
         [LinkNode, LinkNodeFormatter],
         [EmNode, EmNodeFormatter],
         [StrongNode, StrongNodeFormatter],
         [DelNode, DelNodeFormatter],
         [LiteralNode, LiteralNodeFormatter],
         [PluginNode, PluginNodeFormatter],
         [VerbatimLeaf, VerbatimLeafFormatter],
         [CommentOutLeaf, CommentOutLeafFormatter],
         [HeadingLeaf, HeadingLeafFormatter],
         [HrLeaf, HrLeafFormatter],
         [DescNode, DescNodeFormatter],
         [VerbatimNode, VerbatimNodeFormatter],
         [QuoteNode, QuoteNodeFormatter],
         [TableNode, TableNodeFormatter],
         [HeadingNode, HeadingNodeFormatter],
         [ParagraphNode, ParagraphNodeFormatter],
         [ListNode, ListNodeFormatter],
         [EnumNode, EnumNodeFormatter],
         [ListWrapNode, ListWrapNodeFormatter],
         [EnumWrapNode, EnumWrapNodeFormatter]
        ].each  do |node, formatter_class|
          formatter[node] = formatter_class.new(formatter, options)
        end
      end
    end

    ## Definitions of subclasses of MarkDownFormat begins here.

    class InlineLeafFormatter < self
      def visit(leaf, memo)
        leaf.map do |str|
          escaped_str = str.gsub(/([_*])/o, "\\\\\\1")
          if @options.gfm_style
            escaped_str.gsub(/([&<>])/o, "\\\\\\1")
          else
            HtmlElement.escape(escaped_str)
          end
        end
      end
    end

    class LinkNodeFormatter < self
      attr_writer :id_conv_table

      def visit(tree, memo)
        not_from_thumbnail = tree.first.class != LinkNode
        tree = tree.dup
        element = create_self_element
        caption = get_caption(tree, memo)
        if IMAGE_SUFFIX_RE.match? ref_tail(tree, caption) and not_from_thumbnail
          element.push "!"
        end
        link = format_link(tree)
        element.push "[#{(caption || tree).join}](#{link})"
        element
      end

      def get_caption(tree, memo)
        link_sep_index = tree.find_index([LinkSep])
        return nil unless link_sep_index
        caption_part = tree.shift(link_sep_index)
        tree.shift
        caption_part.map {|element| visited_result(element, memo) }
      end

      def format_link(tree)
        link = tree.join
        return link unless @id_conv_table
        if /\A#/o.match? link and gfm_link = @id_conv_table[link[1..-1]]
          "#".concat gfm_link
        else
          link
        end
      end

      def ref_tail(tree, caption)
        tree.last.join
      rescue NoMethodError
        raise NoMethodError unless tree.empty?
        STDERR.puts "No uri is specified for #{caption}"
      end
    end

    class EmNodeFormatter < self
      def tap_element_in_visit(element, tree, memo)
        enclose_in(element, "_")
      end
    end

    class StrongNodeFormatter < self
      def visit(tree, memo)
        super(tree, memo).tap do |element|
          enclose_in(element, "**")
        end
      end
    end

    class DelNodeFormatter < self
      def visit(tree, memo)
        "~~#{super(tree, memo).join.strip}~~"
      end
    end

    class LiteralNodeFormatter < self
      def visit(tree, memo)
        "`#{super(tree, memo).join.strip}`"
      end
    end

    class PluginNodeFormatter < self
      def visit(tree, memo)
        str = tree.join
        return str.strip * 2 if str == " {" or str == "} "
        super(tree, memo)
      end
    end

    class VerbatimLeafFormatter < InlineLeafFormatter
      def visit(leaf, memo)
        leaf.join
      end
    end

    class CommentOutLeafFormatter < self
      def visit(tree, memo); ""; end
    end

    class HeadingLeafFormatter < self
      def tap_element_in_visit(element, tree, memo)
        element.push $/
      end
    end

    class HrLeafFormatter < self
      def visit(tree, memo)
        "----#{$/}"
      end
    end

    class DescNodeFormatter < self
      def visit(tree, memo)
        desc_list = HtmlElement.create("dl").tap do |element|
          element.push HtmlFormat.format(tree)
        end
        remove_trailing_newlines_in_html_element(desc_list)
      end
    end

    class VerbatimNodeFormatter < self
      def visit(tree, memo)
        element = super(tree, memo)
        return gfm_verbatim(element) if @options.gfm_style
        md_verbatim(element)
      end

      def gfm_verbatim(element)
        element.tap do |lines|
          lines.unshift "```#{$/}"
          lines.push "```#{$/ * 2}"
        end
      end

      def md_verbatim(element)
        element.join.gsub(/^/o, "    ").sub(/    \Z/o, "").concat $/
      end
    end

    class QuoteNodeFormatter < self
      def visit(tree, memo)
        element = super(tree, memo)
        element.join.gsub(/^/o, "> ").sub(/> \Z/o, "")
      end
    end

    class TableNodeFormatter < PlainTextFormat::TableNodeFormatter
      class NotConformantStyleError < StandardError; end

      def visit(tree, memo)
        @options.gfm_conformant = check_conformance_with_gfm_style(tree)
        super(tree, memo)
      end

      def choose_expander_of_col_and_row
        ["", ""]
      end

      def format_gfm_table(table)
        cell_width = calculate_cell_width(table)
        header_delimiter = cell_width.map {|width| "-" * width }
        cell_formats = cell_width.map {|width| "%-#{width}s" }
        table[1, 0] = [header_delimiter]
        table.map do |row|
          formatted_row = row.zip(cell_formats).map do |cell, format_str|
            sprintf(format_str, cell)
          end
          "|#{formatted_row.join("|") }|#{$/}"
        end.join + $/
      end

      def format_html_table(tree)
        table = HtmlElement.create("table").tap do |element|
          element.push HtmlFormat.format(tree)
        end.to_s
        @formatter[PlainNode].remove_trailing_newlines_in_html_element(table)
      end

      def format_table(table, tree)
        return format_html_table(tree) unless @options.gfm_style
        return format_gfm_table(table) if @options.gfm_conformant

        if @options.gfm_style == :force
          warning_for_non_comformant_style
          format_gfm_table(table)
        else
          format_html_table(tree)
        end
      end

      def warning_for_non_comformant_style
        warning_message = <<ERROR
The table is not conformant to GFM style.
The first row will be treated as a header row.
ERROR
        raise NotConformantStyleError.new(warning_message)
      rescue
        STDERR.puts warning_message
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

      def check_conformance_with_gfm_style(rows)
        rows.each_with_index do |row, i|
          row.each do |cell|
            return false if cell.rowspan > 1 or cell.colspan > 1
            # A table head row should be at the beginning and composed of <th>
            # elements, and other rows should not include <th> elements
            return false unless (i == 0) == (cell.cell_type == "th")
          end
        end
        true
      end
    end

    class HeadingNodeFormatter < self
      def tap_element_in_visit(element, tree, memo)
        heading_mark = "#" * tree.first.level
        heading_mark << " " unless /^ /o.match? tree.join
        element.unshift heading_mark
      end
    end

    class ParagraphNodeFormatter < self
      def tap_element_in_visit(element, tree, memo)
        element.push $/
      end
    end

    class ListNodeFormatter < self
      def tap_element_in_visit(element, tree, memo)
        element.push $/ if /\A\*/o.match? element.first.join
      end
    end

    class EnumNodeFormatter < self
      def push_visited_results(element, tree, memo)
        memo_with_enum_count = { :original => memo, :enum_item_count => 0 }
        tree.each do |token|
          if token.kind_of? EnumWrapNode
            memo_with_enum_count[:enum_item_count] += 1
          end
          element.push visited_result(token, memo_with_enum_count)
        end
      end

      def tap_element_in_visit(element, tree, memo)
        element.push $/ if /\A\d/o.match? element.first.join
      end
    end

    class ListWrapNodeFormatter < self
      def tap_element_in_visit(element, tree, memo)
        element.unshift list_mark(tree, "*")
      end
    end

    class EnumWrapNodeFormatter < self
      def tap_element_in_visit(element, tree, item_num)
        element.unshift list_mark(tree, "#{item_num[:enum_item_count]}.")
      end
    end
  end
end
