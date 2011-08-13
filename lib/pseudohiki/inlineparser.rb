#/usr/bin/env ruby

require 'treestack'
require 'htmlelement'
require 'pseudohiki/htmlplugin'

module PseudoHiki
  PROTOCOL = /^((https?|file|ftp):|\.?\/)/
  RELATIVE_PATH = /^\./o
  ROOT_PATH = /^(\/|\\\\|[A-Za-z]:\\)/o
  FILE_MARK = "file:///"
  ImageSuffix = /\.(jpg|jpeg|gif|png|bmp)$/io

  def self.compile_token_pat(*token_sets)
    tokens = token_sets.flatten.uniq.sort do |x,y|
      y.length <=> x.length
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

      LinkSep = "|"
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

    TokenPat[self] = PseudoHiki.compile_token_pat(HEAD.keys,TAIL.keys,[LinkSep])

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
  end

  include InlineParser::InlineElement
end

module PseudoHiki
  class HtmlFormat
    include InlineParser::InlineElement

    attr_reader :element_name

    LINK, IMG, EM, STRONG, DEL = %w(a img em strong del)
    HREF, SRC, ALT = %w(href src alt)
    PLAIN, PLUGIN = %w(plain div)

    Formatter = {}

    def initialize(element_name)
      @element_name = element_name
    end

    def visit(tree)
      htmlelement = make_html_element
      tree.each do |element|
        visitor = Formatter[element.class]||Formatter[PlainNode]
        htmlelement.push element.accept(visitor)
      end
      htmlelement
    end

    def make_html_element
      HtmlElement.create(@element_name)
    end

    [[InlineLeaf,nil],
      [LinkNode,LINK],
      [EmNode,EM],
      [StrongNode,STRONG],
      [DelNode,DEL],
      [PlainNode,PLAIN],
      [PluginNode,PLUGIN]
    ].each {|node_class,element| Formatter[node_class] = self.new(element) }

    ImgFormat = self.new(IMG)

    class << Formatter[PlainNode]
      def make_html_element
        []
      end
    end

    class << Formatter[InlineLeaf]
      def visit(leaf)
        HtmlElement.escape(leaf.first)
      end
    end

    class << Formatter[LinkNode]
      def visit(tree)
        caption = nil
        link_sep_index = tree.find_index([LinkSep])
        if link_sep_index
          caption = tree[0,link_sep_index].collect do |element|
            visitor = Formatter[element.class]||Formatter[PlainNode]
            element.accept(visitor)
          end
          tree.shift(link_sep_index+1)
        end
        ref = tree[0][0]
        if ImageSuffix =~ ref
          htmlelement = ImgFormat.make_html_element
          htmlelement[SRC] = ref
          htmlelement[ALT] = caption if caption
        else
          htmlelement = make_html_element
          htmlelement[HREF] = ref
          htmlelement.push caption||ref
        end
        htmlelement
      end
    end

    class << Formatter[PluginNode]
      def visit(leaf)
        HtmlPlugin.new(@element_name,leaf.join).apply
      end
    end

    def self.create_plain
      Formatter[PlainNode]
    end
  end
end
