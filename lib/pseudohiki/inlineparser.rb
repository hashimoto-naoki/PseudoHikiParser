#!/usr/bin/env ruby

require 'pseudohiki/treestack'

module PseudoHiki
  PROTOCOL = /^((https?|file|ftp):|\.?\/)/
  RELATIVE_PATH = /^\./o
  ROOT_PATH = /^(\/|\\\\|[A-Za-z]:\\)/o
  FILE_MARK = "file:///"
  IMAGE_SUFFIX_RE = /\.(jpg|jpeg|gif|png|bmp)$/io

  def self.compile_token_pat(*token_sets)
    tokens = token_sets.flatten.uniq.sort do |x, y|
      [y.length, y] <=> [x.length, x]
    end.collect {|token| Regexp.escape(token) }
    Regexp.new(tokens.join("|"))
  end

  def self.split_into_tokens(str, token_pat)
    tokens = []
    while m = token_pat.match(str)
      tokens.push m.pre_match unless m.pre_match.empty?
      tokens.push m[0]
      str = m.post_match
    end
    tokens.push str unless str.empty?
    tokens
  end

  class InlineParser < TreeStack
    module InlineElement
      class InlineNode < InlineParser::Node; end
      class InlineLeaf < InlineParser::Leaf; end
      # class LinkSepLeaf < InlineLeaf; end

      %w(LinkNode EmNode StrongNode DelNode PlainNode LiteralNode PluginNode).each do |subclass|
        const_set(subclass, Class.new(InlineNode))
      end

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
     [PluginNode, "{{", "}}"]].each do |type, head, tail|
      HEAD[head] = type
      TAIL[tail] = type
      NodeTypeToHead[type] = head
    end

    TokenPat[self] = PseudoHiki.compile_token_pat(HEAD.keys, TAIL.keys, [LinkSep, TableSep, DescSep])

    def initialize(str)
      @tokens = PseudoHiki.split_into_tokens(str, TokenPat[self.class])
      super()
    end

    def convert_last_node_into_leaf
      last_node = remove_current_node
      tag_head = NodeTypeToHead[last_node.class]
      push InlineLeaf.create(tag_head)
      last_node.each {|leaf| push_as_leaf leaf }
    end

    def node_in_ancestors?(node_class)
      not @stack.select {|node| node_class == node.class }.empty?
    end

    def treated_as_node_end(token)
      return pop if current_node.class == TAIL[token]
      return nil unless node_in_ancestors?(TAIL[token])
      convert_last_node_into_leaf until current_node.class == TAIL[token]
      pop
    end

    def parse
      while token = @tokens.shift
        next if TAIL[token] and treated_as_node_end(token)
        next if HEAD[token] and push HEAD[token].new
        push InlineLeaf.create(token)
      end
      self
    end

    def self.parse(str)
      new(str).parse.tree # parser = new(str)
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
        m = MODIFIED_CELL_PAT.match(token_str) and cell_modifiers = m[0]
        return token_str if cell_modifiers.empty?
        @cell_type = TH if cell_modifiers.start_with? TH_PAT
        @rowspan = cell_modifiers.count(ROW_EXPANDER) + 1
        @colspan = cell_modifiers.count(COL_EXPANDER) + 1
        m.post_match
      end

      def parse_first_token(orig_tokens)
        return orig_tokens if orig_tokens.kind_of? InlineParser::InlineNode
        orig_tokens.dup.tap {|tokens| tokens[0] = parse_cellspan(tokens[0]) }
      end

      def push(token)
        return super(token) unless empty?
        super(parse_first_token(token))
      end
    end

    def treated_as_node_end(token)
      return super(token) unless token == TableSep
      pop
      push TableCellNode.new
    end

    def parse
      push TableCellNode.new
      super
    end
  end

  include InlineParser::InlineElement
end
