#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'

module PseudoHiki
  class HtmlFormat
    include InlineParser::InlineElement
    include BlockParser::BlockElement
    include TableRowParser::InlineElement

    #for InlineParser
    LINK, IMG, EM, STRONG, DEL = %w(a img em strong del)
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
        new_formatter[node_class] = formatter.dup
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

    def create_element(element_name, content=nil, attributes={})
      @generator.create(element_name, content, attributes)
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
      tree.each do |element|
        htmlelement.push visited_result(element)
      end
      htmlelement
    end

    def create_self_element(tree=nil)
      create_element(@element_name)
    end

    #for InlineParser

    class LinkNodeFormatter < self
      def visit(tree)
        tree = tree.dup
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
          htmlelement = ImgFormat.create_self_element
          htmlelement[SRC] = tree.join("")
          htmlelement[ALT] = caption.join("") if caption
        else
          htmlelement = create_self_element
          htmlelement[HREF] = tree.join("")
          htmlelement.push caption||tree.join("")
        end
        htmlelement
      end

      def get_caption(tree,link_sep_index)
        tree[0,link_sep_index].collect do |element|
          visited_result(element)
        end
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

    #for BlockParser

    class VerbatimNodeFormatter < self
      def visit(tree)
        create_self_element.configure do |element|
          contents = @generator.escape(tree.join).gsub(BlockParser::URI_RE) do |url|
            create_element("a", url, "href" => url).to_s
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
        super(tree).configure do |element|
          heading_level = "h#{tree.first.nominal_level}"
          element['class'] ||= heading_level
          element['class'] +=  " " + heading_level unless element['class'] == heading_level
        end
      end
    end

    class DescLeafFormatter < self
      def visit(tree)
        tree = tree.dup
        dt = create_self_element(tree)
        dd = create_element(DD)
        element = @generator::Children.new
        element.push dt
        dt_sep_index = tree.index(DescSep)
        if dt_sep_index
          tree.shift(dt_sep_index).each do |token|
            dt.push visited_result(token)
          end
          tree.shift
          unless tree.empty?
            tree.each {|token| dd.push visited_result(token) }
            element.push dd
          end
        else
          tree.each {|token| dt.push visited_result(token) }
        end
        element
      end
    end

    class TableCellNodeFormatter < self
      def visit(tree)
        @element_name = tree.cell_type
        create_self_element.configure do |element|
          element["rowspan"] = tree.rowspan if tree.rowspan > 1
          element["colspan"] = tree.colspan if tree.colspan > 1
          tree.each {|token| element.push visited_result(token) }
        end
      end
    end

    class HeadingLeafFormatter < self
      def create_self_element(tree)
        create_element(@element_name+tree.nominal_level.to_s).configure do |element|
          element["id"] = tree.node_id.upcase if tree.node_id
        end
      end
    end

    class ListLeafNodeFormatter < self
      def create_self_element(tree)
        super(tree).configure do |element|
          element["id"] = tree.node_id.upcase if tree.node_id
        end
      end
    end

    [ [EmNode,EM],
      [StrongNode,STRONG],
      [DelNode,DEL],
      [PluginNode,PLUGIN], #Until here is for InlineParser
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
