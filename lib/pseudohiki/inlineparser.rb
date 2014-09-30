#!/usr/bin/env ruby

require 'pseudohiki/treestack'

module PseudoHiki
  PROTOCOL = /^((https?|file|ftp):|\.?\/)/
  RELATIVE_PATH = /^\./o
  ROOT_PATH = /^(\/|\\\\|[A-Za-z]:\\)/o
  FILE_MARK = "file:///"
  ImageSuffix = /\.(jpg|jpeg|gif|png|bmp)$/io

  def self.subclass_of(parent_class, bound_env, subclass_names)
    subclass_names. each {|name| eval "class #{name} < #{parent_class}; end", bound_env  }
  end

  def self.compile_token_pat(*token_sets)
    tokens = token_sets.flatten.uniq.sort do |x, y|
      [y.length, y] <=> [x.length, x]
    end.collect {|token| Regexp.escape(token) }
    Regexp.new(tokens.join("|"))
  end

  class InlineParser < TreeStack
    module InlineElement
      class InlineNode < InlineParser::Node; end
      class InlineLeaf < InlineParser::Leaf; end
      #  class LinkSepLeaf < InlineLeaf; end

      PseudoHiki.subclass_of(InlineNode, binding,
                             %w(LinkNode EmNode StrongNode DelNode PlainNode LiteralNode PluginNode))

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
     [LiteralNode, "``", "``"],
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
      self.push InlineLeaf.create(tag_head)
      last_node.each {|leaf| self.push_as_leaf leaf }
    end

    def node_in_ancestors?(node_class)
      not @stack.select {|node| node_class == node.class }.empty?
    end

    def treated_as_node_end(token)
      return self.pop if current_node.class == TAIL[token]
      return nil unless node_in_ancestors?(TAIL[token])
      convert_last_node_into_leaf until current_node.class == TAIL[token]
      self.pop
    end

    def split_into_tokens(str)
      tokens = []
      while m = token_pat.match(str)
        tokens.push m.pre_match unless m.pre_match.empty?
        tokens.push m[0]
        str = m.post_match
      end
      tokens.push str unless str.empty?
      tokens
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
      new(str).parse.tree #parser = new(str)
    end
  end

  class TableRowParser < InlineParser
    TD, TH, ROW_EXPANDER, COL_EXPANDER, TH_PAT = %w(td th ^ > !)
    MODIFIED_CELL_PAT = /^!?[>^]*/o

    module InlineElement
      class TableCellNode < InlineParser::InlineElement::InlineNode
        attr_accessor :cell_type, :rowspan, :colspan

        def initialize
          super
          @cell_type, @rowspan, @colspan = TD, 1, 1
        end
      end
    end
    include InlineElement

    TAIL[TableSep] = TableCellNode
    TokenPat[self] = InlineParser::TokenPat[InlineParser]

    class InlineElement::TableCellNode
      def parse_cellspan(token_str)
        return token_str if m = MODIFIED_CELL_PAT.match(token_str) and m[0].empty? #if token.kind_of? String
        cell_modifiers = m[0]
        @cell_type = TH if cell_modifiers[0].chr == TH_PAT
        @rowspan = cell_modifiers.count(ROW_EXPANDER) + 1
        @colspan = cell_modifiers.count(COL_EXPANDER) + 1
        m.post_match
      end

      def parse_first_token(orig_tokens)
        return orig_tokens if orig_tokens.kind_of? InlineParser::InlineNode
        orig_tokens.dup.tap {|tokens| tokens[0] = parse_cellspan(tokens[0]) }
      end

      def push(token)
        return super(token) unless self.empty?
        super(parse_first_token(token))
      end
    end

    def treated_as_node_end(token)
      return super(token) unless token == TableSep
      self.pop
      self.push TableCellNode.new
    end

    def parse
      self.push TableCellNode.new
      super
    end
  end

  include InlineParser::InlineElement
end
