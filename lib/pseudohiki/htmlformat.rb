#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'
require 'htmlelement'

module PseudoHiki
  class HtmlFormat
    include InlineParser::InlineElement
    include BlockParser::BlockElement
    include TableRowParser::InlineElement

    #for InlineParser
    LINK, IMG, EM, STRONG, DEL, LITERAL = %w(a img em strong del code)
    HREF, SRC, ALT = %w(href src alt)
    PLAIN, PLUGIN = %w(plain span)
    #for BlockParser
    DESC, VERB, QUOTE, TABLE, PARA, HR, UL, OL = %w(dl pre blockquote table p hr ul ol)
    SECTION = "section"
    DT, DD, TR, HEADING, LI = %w(dt dd tr h li)
    DescSep = [InlineParser::DescSep]

    Formatter = {}

    attr_reader :element_name
    attr_writer :generator, :formatter

    def self.setup_new_formatter(new_formatter, generator)
      new_formatter.each do |node_class, formatter|
        new_formatter[node_class] = formatter.clone
        new_formatter[node_class].generator = generator
        new_formatter[node_class].formatter = new_formatter
      end
    end

    def self.get_plain
      self::Formatter[PlainNode]
    end

    def self.format(tree)
      formatter = self.get_plain
      tree.accept(formatter)
    end

    def initialize(element_name, generator=HtmlElement)
      @element_name = element_name
      @generator = generator
      @formatter = Formatter
    end

    def visited_result(element)
      visitor = @formatter[element.class]||@formatter[PlainNode]
      element.accept(visitor)
    end

    def push_visited_results(element, tree)
      tree.each {|token| element.push visited_result(token) }
    end

    def visit(tree)
      htmlelement = create_self_element(tree)
      push_visited_results(htmlelement, tree)
      htmlelement
    end

    def create_self_element(tree=nil)
      @generator.create(@element_name)
    end

    def split_into_parts(tree, separator)
      chunks = []
      while sep_index = tree.index(separator)
        chunks.push tree.shift(sep_index)
        tree.shift
      end
      chunks.push tree
    end

    #for InlineParser

    class LinkNodeFormatter < self
      def visit(tree)
        tree = tree.dup
        caption = get_caption(tree)
        begin
          ref = tree.last.join
        rescue NoMethodError
          raise NoMethodError unless tree.empty?
          STDERR.puts "No uri is specified for #{caption}"
        end
        if ImageSuffix =~ ref
          htmlelement = ImgFormat.create_self_element
          htmlelement[SRC] = tree.join
          htmlelement[ALT] = caption.join if caption
        else
          htmlelement = create_self_element
          htmlelement[HREF] = tree.join
          htmlelement.push caption||tree.join
        end
        htmlelement
      end

      def get_caption(tree)
        first_part, second_part = split_into_parts(tree, [LinkSep])
        return nil unless second_part
        first_part.map {|token| visited_result(token) }
      end
    end

    class InlineLeafFormatter < self
      def visit(leaf)
        @generator.escape(leaf.first)
      end
    end

    class PlainNodeFormatter < self
      def create_self_element(tree=nil)
        @generator::Children.new
      end
    end

    class ListLeafNodeFormatter < self
      def create_self_element(tree)
        super(tree).tap do |element|
          element["id"] = tree.node_id.upcase if tree.node_id
        end
      end
    end

    #for BlockParser

    class VerbatimNodeFormatter < self
      def visit(tree)
        create_self_element.tap do |element|
          contents = @generator.escape(tree.join).gsub(BlockParser::URI_RE) do |url|
            @generator.create("a", url, "href" => url).to_s
          end
          element.push contents
        end
      end
    end

    class CommentOutNodeFormatter < self
      def visit(tree); ""; end
    end

    class HeadingNodeFormatter < self
      def create_self_element(tree)
        super(tree).tap do |element|
          heading_level = "h#{tree.first.nominal_level}"
          element['class'] ||= heading_level
          element['class'] +=  " " + heading_level unless element['class'] == heading_level
        end
      end
    end

    class DescLeafFormatter < self
      def visit(tree)
        tree = tree.dup
        element = @generator::Children.new
        dt_part, dd_part = split_into_parts(tree, DescSep)
        dt = super(dt_part)
        element.push dt
        unless dd_part.nil? or dd_part.empty?
          dd = @generator.create(DD)
          push_visited_results(dd, dd_part)
          element.push dd
        end
        element
      end
    end

    class TableCellNodeFormatter < self
      def visit(tree)
        @element_name = tree.cell_type
        super(tree).tap do |element|
          element["rowspan"] = tree.rowspan if tree.rowspan > 1
          element["colspan"] = tree.colspan if tree.colspan > 1
          # element.push "&#160;" if element.empty? # &#160; = &nbsp; this line would be necessary for HTML 4 or XHTML 1.0
        end
      end
    end

    class HeadingLeafFormatter < self
      def create_self_element(tree)
        @generator.create(@element_name+tree.nominal_level.to_s).tap do |element|
          element["id"] = tree.node_id.upcase if tree.node_id
        end
      end
    end

    [ [EmNode, EM],
      [StrongNode, STRONG],
      [DelNode, DEL],
      [LiteralNode, LITERAL],
      [PluginNode, PLUGIN], #Until here is for InlineParser
      [DescNode, DESC],
      [QuoteNode, QUOTE],
      [TableNode, TABLE],
      [ParagraphNode, PARA],
      [HrNode, HR],
      [ListNode, UL],
      [EnumNode, OL],
      [TableLeaf, TR], #Until here is for BlockParser
    ].each {|node_class, element| Formatter[node_class] = self.new(element) }

    #for InlineParser
    ImgFormat = self.new(IMG)
    Formatter[LinkNode] = LinkNodeFormatter.new(LINK)
    Formatter[InlineLeaf] = InlineLeafFormatter.new(nil)
    Formatter[PlainNode] = PlainNodeFormatter.new(PLAIN)
    #for BlockParser
    Formatter[VerbatimNode] = VerbatimNodeFormatter.new(VERB)
    Formatter[CommentOutNode] = CommentOutNodeFormatter.new(nil)
    Formatter[HeadingNode] = HeadingNodeFormatter.new(SECTION)
    Formatter[DescLeaf] = DescLeafFormatter.new(DT)
    Formatter[TableCellNode] = TableCellNodeFormatter.new(nil)
    Formatter[HeadingLeaf] = HeadingLeafFormatter.new(HEADING)
    Formatter[ListWrapNode] = ListLeafNodeFormatter.new(LI)
    Formatter[EnumWrapNode] = ListLeafNodeFormatter.new(LI)

    class << Formatter[PluginNode]
      def visit(tree)
        str = tree.join
        return str if InlineParser::HEAD[str] or InlineParser::TAIL[str]
        return str.strip * 2 if str == ' {' or str == '} '
        super(tree)
      end
    end
  end

  class XhtmlFormat < HtmlFormat
    Formatter = HtmlFormat::Formatter.dup
    setup_new_formatter(Formatter, XhtmlElement)
  end

  class Xhtml5Format < XhtmlFormat
    Formatter = HtmlFormat::Formatter.dup
    setup_new_formatter(Formatter, Xhtml5Element)
  end
end
