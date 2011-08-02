#/usr/bin/env ruby

require 'treestack'

class PseudoHikiInlineParser
  class InlineStack < TreeStack
    def convert_last_node_into_leaf
      last_node = self.pop
      self.current_node.pop
      tag_head = NodeTypeToHead[last_node.class]
      tag_head_leaf = InlineLeaf.create(tag_head)
      self.push tag_head_leaf
      last_node.each {|leaf| self.push leaf }
    end

    def node_in_ancestor?(node_class)
      @stack.select {|node| node_class == node.class }
    end
  end

  class InlineNode < TreeStack::Node;end
  class InlineLeaf < TreeStack::Leaf; end

  class LinkNode < InlineNode; end
  class EmNode < InlineNode; end
  class StrongNode < InlineNode; end
  class DelNode < InlineNode; end
  class PlainNode < InlineNode; end
  class PluginNode < InlineNode; end
  
  LINK, IMG, EM, STRONG, DEL = %w(a img em strong del)
  HREF, SRC, ALT = %w(href src alt)

  LinkSep, PLAIN, PLUGIN = %w(| plain div)

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
      end.collect {|token| Regexp.escape(token) }
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
    result
  end

  def parse
    while token = @tokens.shift
      next if TAIL[token] and treated_as_node_end(token)
      next if HEAD[token] and @stack.push HEAD[token].new
      @stack.push InlineLeaf.create(token)
    end
    @stack
  end

  def treated_as_node_end(token)
    return @stack.pop if @stack.current_node.class == TAIL[token]
    nil
  end
end
