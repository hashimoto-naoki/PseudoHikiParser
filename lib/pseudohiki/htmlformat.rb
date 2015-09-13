#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'
require 'htmlelement'

module PseudoHiki
  class HtmlFormat
    include InlineParser::InlineElement
    include BlockParser::BlockElement
    include TableRowParser::InlineElement

    # for InlineParser
    LINK, LITERAL, PLUGIN = %w(a code span)
    BLANK, SPACE = "", " "
    HREF, SRC, ALT, ID, CLASS, ROWSPAN, COLSPAN = %w(href src alt id class rowspan colspan)
    # for BlockParser
    DT, DD, LI = %w(dt dd li)
    DescSep, LinkSep = [InlineParser::DescSep], [InlineParser::LinkSep]

    Formatter = {}

    class << self
      attr_accessor :disable_auto_link_in_verbatim
    end

    attr_reader :element_name
    attr_writer :generator, :formatter, :format_class

    def self.setup_new_formatter(new_formatter, generator)
      new_formatter.each do |node_class, formatter|
        new_formatter[node_class] = formatter.clone
        new_formatter[node_class].generator = generator
        new_formatter[node_class].formatter = new_formatter
        new_formatter[node_class].format_class = self
      end
    end

    def self.get_plain
      self::Formatter[PlainNode]
    end

    def self.create(options=nil)
      self
    end

    def self.format(tree)
      formatter = get_plain
      tree.accept(formatter)
    end

    def initialize(element_name, generator=HtmlElement)
      @element_name = element_name
      @generator = generator
      @formatter = Formatter
    end

    def visited_result(element)
      visitor = @formatter[element.class] || @formatter[PlainNode]
      element.accept(visitor)
    end

    def push_visited_results(element, tree)
      tree.each {|token| element.push visited_result(token) }
    end

    def visit(tree)
      htmlelement = create_element(tree)
      push_visited_results(htmlelement, tree)
      htmlelement
    end

    def create_element(tree=nil)
      @generator.create(@element_name)
    end

    def split_into_parts(tree, separator)
      chunks = []
      tree = tree.dup
      while sep_index = tree.index(separator)
        chunks.push tree.shift(sep_index)
        tree.shift
      end
      chunks.push tree
    end

    class ListLeafNodeFormatter < self
      def create_element(tree)
        super(tree).tap do |elm|
          elm[ID] = tree.node_id.upcase if tree.node_id
        end
      end
    end

    [[EmNode, "em"],
     [StrongNode, "strong"],
     [DelNode, "del"],
     [LiteralNode, LITERAL],
     [PluginNode, PLUGIN],
     [LinkNode, LINK],
     [InlineLeaf, nil],
     [PlainNode, nil], # Until here is for InlineParser
     [DescNode, "dl"],
     [QuoteNode, "blockquote"],
     [TableNode, "table"],
     [ParagraphNode, "p"],
     [HrNode, "hr"],
     [ListNode, "ul"],
     [EnumNode, "ol"],
     [TableLeaf, "tr"],
     [VerbatimNode, "pre"],
     [CommentOutNode, nil],
     [HeadingNode, "section"],
     [DescLeaf, DT],
     [TableCellNode, nil],
     [HeadingLeaf, "h"], # Until here is for BlockParser
    ].each {|node_class, elm| Formatter[node_class] = new(elm) }

    # for InlineParser
    ImgFormat = new("img")
    # for BlockParser
    Formatter[ListWrapNode] = ListLeafNodeFormatter.new(LI)
    Formatter[EnumWrapNode] = ListLeafNodeFormatter.new(LI)

    # for InlineParser

    class << Formatter[PluginNode]
      def visit(tree)
        escape_inline_tags(tree) { super(tree) }
      end

      def escape_inline_tags(tree)
        str = tree.join
        return str if InlineParser::HEAD[str] or InlineParser::TAIL[str]
        return str.strip * 2 if str == ' {' or str == '} '
        yield
      end
    end

    class << Formatter[LinkNode]
      def visit(tree)
        not_from_thumbnail = tree.first.class != LinkNode
        caption, ref = caption_and_ref(tree)
        if IMAGE_SUFFIX_RE =~ ref and not_from_thumbnail
          htmlelement = ImgFormat.create_element
          htmlelement[SRC] = ref
          htmlelement[ALT] = caption.join if caption
        else
          htmlelement = create_element
          htmlelement[HREF] = ref.start_with?("#".freeze) ? ref.upcase : ref
          htmlelement.push caption || ref
        end
        htmlelement
      end

      def caption_and_ref(tree)
        caption, ref = split_into_parts(tree, LinkSep)
        caption = ref ? caption.map {|token| visited_result(token) } : nil
        return caption, (ref || tree).join
      rescue NoMethodError
        raise NoMethodError unless (ref || tree).empty?
        STDERR.puts "No uri is specified for #{caption}"
      end
    end

    class << Formatter[InlineLeaf]
      def visit(leaf)
        @generator.escape(leaf.first)
      end
    end

    class << Formatter[PlainNode]
      def create_element(tree=nil)
        @generator::Children.new
      end
    end

    # for BlockParser

    class << Formatter[VerbatimNode]
      def visit(tree)
        contents = add_link(@generator.escape(tree.join))
        create_element.tap {|elm| elm.push contents }
      end

      def add_link(verbatim)
        return verbatim if @format_class.disable_auto_link_in_verbatim
        verbatim.gsub(AutoLink::URI_RE) do |url|
          @generator.create(LINK, url, HREF => url).to_s
        end
      end
    end

    class << Formatter[CommentOutNode]
      def visit(tree); BLANK; end
    end

    class << Formatter[HeadingNode]
      def create_element(tree)
        super(tree).tap do |elm|
          heading_level = "h#{tree.first.level}"
          elm[CLASS] ||= heading_level
          elm[CLASS] += SPACE + heading_level unless elm[CLASS] == heading_level
        end
      end
    end

    class << Formatter[DescLeaf]
      def visit(tree)
        elm = @generator::Children.new
        dt_part, dd_part = split_into_parts(tree, DescSep)
        dt = super(dt_part)
        elm.push dt
        unless dd_part.nil? or dd_part.empty?
          dd = @generator.create(DD)
          push_visited_results(dd, dd_part)
          elm.push dd
        end
        elm
      end
    end

    class << Formatter[TableCellNode]
      def visit(tree)
        @element_name = tree.cell_type
        super(tree).tap do |elm|
          elm[ROWSPAN] = tree.rowspan if tree.rowspan > 1
          elm[COLSPAN] = tree.colspan if tree.colspan > 1
          # elm.push "&#160;" if elm.empty? # &#160; = &nbsp; this line would be necessary for HTML 4 or XHTML 1.0
        end
      end
    end

    class << Formatter[HeadingLeaf]
      def create_element(tree)
        @generator.create(@element_name + tree.level.to_s).tap do |elm|
          elm[ID] = tree.node_id.upcase if tree.node_id
        end
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
