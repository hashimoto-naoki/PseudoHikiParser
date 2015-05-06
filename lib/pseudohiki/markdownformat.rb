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

    def self.format(tree, options={ :strict_mode=> false, :gfm_style => false })
      if Formatters.empty?
        default_options = { :strict_mode=> false, :gfm_style => false }
        Formatters[default_options] = create(default_options)
      end

      Formatters[options] ||= create(options)
      Formatters[options].format(tree)
    end

    def self.convert_to_gfm_id_format(heading)
      heading.gsub(GFM_STRIPPED_CHARS_PAT) do |char|
        /\A\s+\Z/o =~ char ? '-'.freeze : ''.freeze
      end.downcase
    end

    def initialize(formatter={}, options={ :strict_mode=> false, :gfm_style => false })
      @formatter = formatter
      options_given_via_block = nil
      if block_given?
        options_given_via_block = yield
        options.merge!(options_given_via_block)
      end
      @options = OpenStruct.new(options)
    end

    def create_self_element(tree=nil)
      HtmlElement::Children.new
    end

    def visited_result(node)
      visitor = @formatter[node.class]||@formatter[PlainNode]
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
      @formatter[LinkNode].id_conv_table = prepare_id_conv_table(tree) if @options.gfm_style
      tree.accept(formatter).join
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

    def remove_trailing_newlines_in_html_element(element)
      element.to_s.gsub(/([^>])\r?\n/, "\\1") << $/
    end

    def collect_headings(tree)
      PseudoHiki::Utils::NodeCollector.select(tree) do |node|
        node.kind_of? PseudoHiki::BlockParser::HeadingLeaf
      end
    end

    def prepare_id_conv_table(tree)
      {}.tap do |table|
        collect_headings(tree).each do |heading|
          if node_id = heading.node_id
            heading_text = PlainTextFormat.format(heading).strip
            table[node_id] = MarkDownFormat.convert_to_gfm_id_format(heading_text)
          end
        end
      end
    end

    def self.create(options={ :strict_mode => false })
      formatter = {}
      main_formatter = self.new(formatter, options)
      formatter.default = main_formatter

#      formatter[PlainNode] = PlainNodeFormatter.new(formatter, options)
#      formatter[InlineNode] = InlineNodeFormatter.new(formatter, options)
      formatter[InlineLeaf] = InlineLeafFormatter.new(formatter, options)
      formatter[LinkNode] = LinkNodeFormatter.new(formatter, options)
      formatter[EmNode] = EmNodeFormatter.new(formatter, options)
      formatter[StrongNode] = StrongNodeFormatter.new(formatter, options)
      formatter[DelNode] = DelNodeFormatter.new(formatter, options)
      formatter[LiteralNode] = LiteralNodeFormatter.new(formatter, options)
      formatter[PluginNode] = PluginNodeFormatter.new(formatter, options)
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
      formatter[DescNode] = DescNodeFormatter.new(formatter, options)
      formatter[VerbatimNode] = VerbatimNodeFormatter.new(formatter, options)
      formatter[QuoteNode] = QuoteNodeFormatter.new(formatter, options)
      formatter[TableNode] = TableNodeFormatter.new(formatter, options)
#      formatter[CommentOutNode] = CommentOutNodeFormatter.new(formatter, options)
      formatter[HeadingNode] = HeadingNodeFormatter.new(formatter, options)
      formatter[ParagraphNode] = ParagraphNodeFormatter.new(formatter, options)
#      formatter[HrNode] = HrNodeFormatter.new(formatter, options)
      formatter[ListNode] = ListNodeFormatter.new(formatter, options)
      formatter[EnumNode] = EnumNodeFormatter.new(formatter, options)
      formatter[ListWrapNode] = ListWrapNodeFormatter.new(formatter, options)
      formatter[EnumWrapNode] = EnumWrapNodeFormatter.new(formatter, options)

      main_formatter
    end

## Definitions of subclasses of MarkDownFormat begins here.

#    class PlainNodeFormatter < self; end
#    class InlineNodeFormatter < self; end

    class InlineLeafFormatter < self
      def visit(leaf)
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

      def visit(tree)
        not_from_thumbnail = tree.first.class != LinkNode
        tree = tree.dup
        element = create_self_element
        caption = get_caption(tree)
        begin
          ref = tree.last.join
        rescue NoMethodError
          raise NoMethodError unless tree.empty?
          STDERR.puts "No uri is specified for #{caption}"
        end
        element.push "!" if ImageSuffix =~ ref and not_from_thumbnail
        link = format_link(tree)
        element.push "[#{(caption||tree).join}](#{link})"
        element
      end

      def get_caption(tree)
        link_sep_index = tree.find_index([LinkSep])
        return nil unless link_sep_index
        caption_part = tree.shift(link_sep_index)
        tree.shift
        caption_part.map {|element| visited_result(element) }
      end

      def format_link(tree)
        link = tree.join
        return link unless @id_conv_table
        if /\A#/o =~ link and gfm_link = @id_conv_table[link[1..-1]]
          "#".concat gfm_link
        else
          link
        end
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
        "~~#{super(tree).join.strip}~~"
      end
    end

    class LiteralNodeFormatter < self
      def visit(tree)
        "`#{super(tree).join.strip}`"
      end
    end

    class PluginNodeFormatter < self
      def visit(tree)
        str =tree.join
        return str.strip * 2 if str == " {" or str == "} "
        super(tree)
      end
    end

#    class DescLeafFormatter < self; end
#    class TableCellNodeFormatter < self; end

    class VerbatimLeafFormatter < InlineLeafFormatter
      def visit(leaf)
        leaf.join
      end
    end

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
    class DescNodeFormatter < self
      def visit(tree)
        desc_list = HtmlElement.create("dl").tap do |element|
          element.push HtmlFormat.format(tree)
        end
        remove_trailing_newlines_in_html_element(desc_list)
      end
    end

    class VerbatimNodeFormatter < self
      def visit(tree)
        element = super(tree)
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
      def visit(tree)
        element = super(tree)
        element.join.gsub(/^/o, "> ").sub(/> \Z/o, "")
      end
    end

    class TableNodeFormatter < PlainTextFormat::TableNodeFormatter
      class NotConformantStyleError < StandardError; end

      def visit(tree)
        @options.gfm_conformant = check_conformance_with_gfm_style(tree)
        super(tree)
      end

      def choose_expander_of_col_and_row
        ["", ""]
      end

      def format_gfm_table(table)
        cell_width = calculate_cell_width(table)
        header_delimiter = cell_width.map {|width| "-" * width }
        cell_formats = cell_width.map {|width| "%-#{width}s" }
        table[1,0] = [header_delimiter]
        table.map do |row|
          formatted_row = row.zip(cell_formats).map do |cell, format|
            format%[cell]
          end
          "|#{formatted_row.join("|") }|#{$/}"
        end.join+$/
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
          begin
            raise NotConformantStyleError.new("The table is not conformant to GFM style. The first row will be treated as a header row.")
          rescue
            STDERR.puts "The table is not conformant to GFM style. The first row will be treated as a header row."
          end
          return format_gfm_table(table)
        end

        format_html_table(tree)
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
            #A table head row should be at the beginning and composed of <th> elements,
            #and other rows should not include <th> elements
            return false unless (i == 0) == (cell.cell_type == "th")
          end
        end
        true
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

    class ListNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          if /\A\*/o =~ element.first.join
            element.push $/
          end
        end
      end
    end

    class EnumNodeFormatter < self
      def visit(tree)
        super(tree).tap do |element|
          if /\A\d/o =~ element.first.join
            element.push $/
          end
        end
      end
    end

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
