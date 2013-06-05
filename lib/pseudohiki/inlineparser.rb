#!/usr/bin/env ruby

require 'treestack'
require 'htmlelement'

module PseudoHiki
  PROTOCOL = /^((https?|file|ftp):|\.?\/)/
  RELATIVE_PATH = /^\./o
  ROOT_PATH = /^(\/|\\\\|[A-Za-z]:\\)/o
  FILE_MARK = "file:///"
  ImageSuffix = /\.(jpg|jpeg|gif|png|bmp)$/io

  def self.compile_token_pat(*token_sets)
    tokens = token_sets.flatten.uniq.sort do |x,y|
      [y.length, y] <=> [x.length, x]
    end.collect {|token| Regexp.escape(token) }
    Regexp.new(tokens.join("|"))
  end

  class InlineParser < TreeStack
    module InlineElement
      class InlineNode < InlineParser::Node;end
      class InlineLeaf < InlineParser::Leaf; end
      #  class LinkSepLeaf < InlineLeaf; end

      class LinkNode < InlineNode; end
      class EmNode < InlineNode; end
      class StrongNode < InlineNode; end
      class DelNode < InlineNode; end
      class PlainNode < InlineNode; end
      class PluginNode < InlineNode; end

      LinkSep, TableSep, DescSep = %w(| || :)
    end
    include InlineElement

    HEAD = {}
    TAIL = {}
    NodeTypeToHead = {}
    TokenPat = {}
    
    [[LinkNode, "[[", "]]"],
     [EmNode, "''", "''"],
     [StrongNode, "'''", "'''"],
     [DelNode, "==", "=="],
     [PluginNode, "{{","}}"]].each do |type, head, tail|
      HEAD[head] = type
      TAIL[tail] = type
      NodeTypeToHead[type] = head
    end

    TokenPat[self] = PseudoHiki.compile_token_pat(HEAD.keys,TAIL.keys,[LinkSep, TableSep, DescSep])

    def token_pat
      TokenPat[self.class]
    end

    def initialize(str)
      @tokens = split_into_tokens(str)
      super()
    end

    def convert_last_node_into_leaf
      last_node = remove_current_node
      tag_head = NodeTypeToHead[last_node.class]
      tag_head_leaf = InlineLeaf.create(tag_head)
      self.push tag_head_leaf
      last_node.each {|leaf| self.push_as_leaf leaf }
    end

    def node_in_ancestors?(node_class)
      not @stack.select {|node| node_class == node.class }.empty?
    end

    def treated_as_node_end(token)
      return self.pop if current_node.class == TAIL[token]
      if node_in_ancestors?(TAIL[token])
        convert_last_node_into_leaf until current_node.class == TAIL[token]
        return self.pop
      end
      nil
    end

    def split_into_tokens(str)
      result = []
      while m = token_pat.match(str)
        result.push m.pre_match if m.pre_match
        result.push m[0]
        str = m.post_match
      end
      result.push str unless str.empty?
      result.delete_if {|token| token.empty? }
      result
    end

    def parse
      while token = @tokens.shift
        next if TAIL[token] and treated_as_node_end(token)
        next if HEAD[token] and self.push HEAD[token].new
        self.push InlineLeaf.create(token)
      end
      self
    end

    def self.parse(str)
      parser = new(str)
      parser.parse.tree
    end
  end

  class TableRowParser < InlineParser
    module InlineElement
      class TableCellNode < InlineParser::InlineElement::InlineNode
        attr_accessor :cell_type, :rowspan, :colspan
      end
    end
    include InlineElement

    TAIL[TableSep] = TableCellNode
    TokenPat[self] = InlineParser::TokenPat[InlineParser]

    TD, TH, ROW_EXPANDER, COL_EXPANDER, TH_PAT = %w(td th ^ > !)
    MODIFIED_CELL_PAT = /^!?[>^]*/o

    class InlineElement::TableCellNode

      def parse_first_token(token)
        @cell_type, @rowspan, @colspan, parsed_token = TD, 1, 1, token.dup
        token_str = parsed_token[0]
        m = MODIFIED_CELL_PAT.match(token_str) #if token.kind_of? String

        if m
          cell_modifiers = m[0].split(//o)
          if cell_modifiers.first == TH_PAT
            cell_modifiers.shift
            @cell_type = TH
          end
          parsed_token[0] = token_str.sub(MODIFIED_CELL_PAT,"")
          row_width = cell_modifiers.count(ROW_EXPANDER) + 1
          @rowspan = row_width if row_width > 1
          col_width = cell_modifiers.count(COL_EXPANDER) + 1
          @colspan = col_width if col_width > 1
        end
        parsed_token
      end

      def push(token)
        if self.empty?
          super(parse_first_token(token))
        else
          super(token)
        end
      end
    end

    def treated_as_node_end(token)
      if token == TableSep
        self.pop
        return (self.push TableCellNode.new)
      end

      super(token)
    end

    def parse
      self.push TableCellNode.new
      super
    end
  end

  include InlineParser::InlineElement
end

module PseudoHiki
  class HtmlFormat
    include InlineParser::InlineElement

    attr_reader :element_name

    LINK, IMG, EM, STRONG, DEL = %w(a img em strong del)
    HREF, SRC, ALT = %w(href src alt)
    PLAIN, PLUGIN = %w(plain span)

    Formatter = {}

    def initialize(element_name)
      @element_name = element_name
    end

    def create_element(element_name, content=nil)
      HtmlElement.create(element_name, content)
    end

    def visited_result(element)
      visitor = Formatter[element.class]||Formatter[PlainNode]
      element.accept(visitor)
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
        HtmlElement.escape(leaf.first)
      end
    end

    class PlainNodeFormatter < self
      def create_self_element(tree=nil)
        HtmlElement::Children.new
      end
    end

    [ [EmNode,EM],
      [StrongNode,STRONG],
      [DelNode,DEL],
      [PluginNode,PLUGIN]
    ].each {|node_class,element| Formatter[node_class] = self.new(element) }

    ImgFormat = self.new(IMG)
    Formatter[LinkNode] = LinkNodeFormatter.new(LINK)
    Formatter[InlineLeaf] = InlineLeafFormatter.new(nil)
    Formatter[PlainNode] = PlainNodeFormatter.new(PLAIN)

    def self.get_plain
      self::Formatter[PlainNode]
    end

    def self.format(tree)
      formatter = self.get_plain
      tree.accept(formatter)
    end
  end
end
