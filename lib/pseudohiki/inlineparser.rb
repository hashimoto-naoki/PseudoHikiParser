#/usr/bin/env ruby

require 'treestack'
require 'htmlelement'

class PseudoHikiInlineParser
  class InlineStack < TreeStack
    def convert_last_node_into_leaf
      last_node = self.pop
      self.current_node.pop
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
  end

  class InlineNode < TreeStack::Node;end
  class InlineLeaf < TreeStack::Leaf; end
#  class LinkSepLeaf < InlineLeaf; end

  class LinkNode < InlineNode; end
  class EmNode < InlineNode; end
  class StrongNode < InlineNode; end
  class DelNode < InlineNode; end
  class PlainNode < InlineNode; end
  class PluginNode < InlineNode; end

  LinkSep = "|"

  PROTOCOL = /^((https?|file|ftp):|\.?\/)/
  RELATIVE_PATH = /^\./o
  ROOT_PATH = /^(\/|\\\\|[A-Za-z]:\\)/o
  FILE_MARK = "file:///"
  ImageSuffix = /\.(jpg|jpeg|gif|png|bmp)$/io

  HEAD = {}
  TAIL = {}
  NodeTypeToHead = {}

  [[LinkNode, "[[", "]]"],
   [EmNode, "''", "''"],
   [StrongNode, "'''", "'''"],
   [DelNode, "==", "=="],
   [PluginNode, "{{","}}"]].each do |type, head, tail|
    HEAD[head] = type
    TAIL[tail] = type
    NodeTypeToHead[type] = head
  end

  def self.compile_token_pat
    unless class_variable_defined? :@@token_pat
      tokens = HEAD.keys.concat(TAIL.keys).uniq.sort do |x,y|
        y.length <=> x.length
      end.concat([LinkSep]).collect {|token| Regexp.escape(token) }
      @@token_pat = Regexp.new(tokens.join("|"))
    end
    @@token_pat
  end
  compile_token_pat

  def initialize(str="")
    @stack = InlineStack.new
    @tokens = split_into_tokens(str)
  end

  def token_pat
    @@token_pat
  end

  def split_into_tokens(str)
    result = []
    while m = @@token_pat.match(str)
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
      next if TAIL[token] and @stack.treated_as_node_end(token)
      next if HEAD[token] and @stack.push HEAD[token].new
      @stack.push InlineLeaf.create(token)
    end
    @stack
  end
end

class PseudoHikiInlineParser
  class HtmlFormat
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
        visitor = Formatter[element.class]||PlainFormat
        htmlelement.push element.accept(visitor)
      end
      htmlelement
    end

    def make_html_element
      HtmlElement.create(@element_name)
    end

    LeafFormat = self.new(nil)
    LinkFormat = self.new(LINK)
    ImgFormat = self.new(IMG)
    EmFormat = self.new(EM)
    StrongFormat = self.new(STRONG)
    DelFormat = self.new(DEL)
    PlainFormat = self.new(PLAIN)
    PluginFormat = self.new(PLUGIN)

    class <<PlainFormat
      def make_html_element
        []
      end
    end

    class <<LeafFormat
      def visit(leaf)
        leaf.join("")
      end
    end

    class <<LinkFormat
       def visit(tree)
         caption = nil
         link_sep_index = tree.find_index([LinkSep])
         if link_sep_index
           caption = tree[0,link_sep_index].collect do |element|
             visitor = Formatter[element.class]||PlainFormat
             element.accept(visitor)
           end
           tree.shift(link_sep_index+1)
         end
         ref = tree[0][0]
         if ImageSuffix =~ ref
           htmlelement = ImgFormat.make_html_element
           htmlelement[SRC] = ref
           htmlelement[ALT] = caption
         else
           htmlelement = make_html_element
           htmlelement[HREF] = ref
           htmlelement.push caption||ref
         end
         htmlelement
       end
    end

    [[InlineLeaf,LeafFormat],
      [LinkNode,LinkFormat],
      [EmNode,EmFormat],
      [StrongNode,StrongFormat],
      [DelNode,DelFormat],
      [PlainNode,PlainFormat],
      [PluginNode,PluginFormat]
    ].each {|node_class,format| Formatter[node_class] = format }

    def self.create_plain
      PlainFormat
    end
  end
end
