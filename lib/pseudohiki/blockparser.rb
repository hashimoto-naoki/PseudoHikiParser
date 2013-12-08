#!/usr/bin/env ruby

require 'pseudohiki/treestack'
require 'pseudohiki/inlineparser'

module PseudoHiki
  class BlockParser
    URI_RE = /(?:(?:https?|ftp|file):|mailto:)[A-Za-z0-9;\/?:@&=+$,\-_.!~*\'()#%]+/ #borrowed from hikidoc
    ID_TAG_PAT = /^\[([^\[\]]+)\]/o

    module LINE_PAT
      VERBATIM_BEGIN = /\A(<<<\s*)/o
      VERBATIM_END = /\A(>>>\s*)/o
      PLUGIN_BEGIN = /\{\{/o
      PLUGIN_END = /\}\}/o
    end

    ParentNode = {}
    HeadToLeaf = {}

    attr_reader :stack

    def self.assign_node_id(leaf, node)
#      return unless tree[0].kind_of? Array ** block_leaf:[inline_node:[token or inline_node]]
      head = leaf[0]
      return unless head.kind_of? String
      m = ID_TAG_PAT.match(head)
      if m
        node.node_id = m[1]
        leaf[0] = head.sub(ID_TAG_PAT,"")
      end
      node
    end

    def self.parse(lines)
      parser = self.new
      parser.read_lines(lines)
      parser.stack.tree
    end

    class BlockStack < TreeStack
      def pop
        self.current_node.parse_leafs
        super
      end
    end

    class BlockLeaf < BlockStack::Leaf
      @@head_re = {}
      attr_accessor :nominal_level
      attr_accessor :node_id

      def self.head_re=(head_regex)
        @@head_re[self] = head_regex
      end

      def self.head_re
        @@head_re[self]
      end

      def self.with_depth?
        false
      end

      def self.create(line, inline_parser=InlineParser)
        line.sub!(self.head_re,"") if self.head_re
        leaf = self.new
        leaf.concat(inline_parser.parse(line))
      end

      def self.assign_head_re(head, need_to_escape=true, reg_pat="(%s)")
        head = Regexp.escape(head) if need_to_escape
        self.head_re = Regexp.new('\\A'+reg_pat%[head])
      end

      def head_re
        @@head_re[self.class]
      end

      def block
        ParentNode[self.class]
      end

      def push_block(stack)
        stack.push(block.new)
      end

      def under_appropriate_block?(stack)
        stack.current_node.kind_of? block and stack.current_node.nominal_level == nominal_level
      end

      def push_self(stack)
        push_block(stack) unless under_appropriate_block?(stack)
        super(stack)
      end

      def parse_leafs
        parsed = InlineParser.parse(self.join)
        self.clear
        self.concat(parsed)
      end
    end

    class NonNestedBlockLeaf < BlockLeaf
      include TreeStack::Mergeable

      def self.create(line)
        line.sub!(self.head_re,"") if self.head_re
        self.new.tap {|leaf| leaf.push line }
      end

      def push_self(stack)
        push_block(stack) unless under_appropriate_block?(stack)
        if stack.last_leaf.kind_of? self.class
          stack.last_leaf.merge(self)
        else
          super(stack)
        end
      end
    end

    class NestedBlockLeaf < BlockLeaf
      def self.assign_head_re(head, need_to_escape)
        super(head, need_to_escape, "(%s)+")
      end

      def self.create(line)
        m = self.head_re.match(line)
        super(line).tap {|leaf| leaf.nominal_level = m[0].length }
      end

      def self.with_depth?
        true
      end

      def push_self(stack)
        super(stack)
        BlockParser.assign_node_id(self[0], self)
      end
    end

    class ListTypeLeaf < NestedBlockLeaf; end

    class BlockNode < BlockStack::Node
      attr_accessor :base_level, :relative_level_from_base
      attr_accessor :node_id

      def nominal_level
        return nil unless first
        first.nominal_level
      end

      def push_self(stack)
        @stack = stack
        super(stack)
      end

      def breakable?(breaker)
        not (kind_of?(breaker.block) and nominal_level == breaker.nominal_level)
      end

      def parse_leafs; end

      def in_link_tag?(preceding_str)
        preceding_str[-2,2] == "[[" or preceding_str[-1,1] == "|"
      end

      def tagfy_link(line)
        line.gsub(URI_RE) {|url| in_link_tag?($`) ? url : "[[#{url}]]" }
      end

      def add_leaf(line, verbatim_leaf=VerbatimLeaf, blockparser)
        if LINE_PAT::VERBATIM_BEGIN =~ line
          return blockparser.stack.push verbatim_leaf.new.block.new.tap {|node| node.in_block_tag = true }
        end
        line = tagfy_link(line) unless verbatim_leaf.head_re =~ line
        leaf = blockparser.select_leaf_type(line).create(line)
        while blockparser.breakable?(leaf)
          blockparser.stack.pop
        end
        blockparser.stack.push leaf
      end
    end

    class NonNestedBlockNode < BlockNode
      def parse_leafs
        self.each {|leaf| leaf.parse_leafs }
      end
    end

    class NestedBlockNode < BlockNode; end

    class ListTypeBlockNode < NestedBlockNode
      def breakable?(breaker)
        not (breaker.block.superclass == ListTypeBlockNode and nominal_level <= breaker.nominal_level)
      end
    end

    class ListLeafNode < NestedBlockNode
      def breakable?(breaker)
        not (breaker.kind_of?(ListTypeLeaf) and nominal_level < breaker.nominal_level)
      end
    end

    module BlockElement
      {
        BlockLeaf => %w(DescLeaf VerbatimLeaf TableLeaf CommentOutLeaf BlockNodeEnd HrLeaf),
        NonNestedBlockLeaf => %w(QuoteLeaf ParagraphLeaf),
        NestedBlockLeaf => %w(HeadingLeaf),
        ListTypeLeaf => %w(ListLeaf EnumLeaf),
        BlockNode => %w(DescNode VerbatimNode TableNode CommentOutNode HrNode),
        NonNestedBlockNode => %w(QuoteNode ParagraphNode),
        NestedBlockNode => %w(HeadingNode),
        ListTypeBlockNode => %w(ListNode EnumNode),
        ListLeafNode => %w(ListWrapNode EnumWrapNode)
      }.each do |parent_class, children|
        PseudoHiki.subclass_of(parent_class, binding, children)
      end
    end
    include BlockElement

    class BlockElement::BlockNodeEnd
      def push_self(stack); end
    end

    class BlockElement::VerbatimNode
      attr_writer :in_block_tag

      def add_leaf(line, verbatim_leaf, blockparser)
        return @stack.pop if LINE_PAT::VERBATIM_END =~ line

        if @in_block_tag
          line = " ".concat(line) if BlockElement::BlockNodeEnd.head_re =~ line
          blockparser.stack.push verbatim_leaf.create(line)
        else
          super(line, verbatim_leaf, blockparser)
        end
      end
    end

    class BlockElement::QuoteNode
      def parse_leafs
        self[0] = BlockParser.parse(self[0])
      end
    end

#    class HeadingNode
    class BlockElement::HeadingNode
      def breakable?(breaker)
        kind_of?(breaker.block) and nominal_level >= breaker.nominal_level
      end
    end

    class BlockElement::VerbatimLeaf
      def self.create(line)
        line.sub!(self.head_re,"") if self.head_re
        self.new.tap {|leaf| leaf.push line }
      end
    end

    class BlockElement::TableLeaf
      def self.create(line)
        super(line, TableRowParser)
      end
    end

    class ListTypeLeaf
      include BlockElement

      Wrapper = {
        ListLeaf => ListWrapNode,
        EnumLeaf => EnumWrapNode
      }

      def push_self(stack)
        push_block(stack) unless under_appropriate_block?(stack)
        stack.push Wrapper[self.class].new
        BlockParser.assign_node_id(self[0], stack.current_node)
        stack.push_as_leaf self
      end
    end

    [[DescLeaf, DescNode],
     [VerbatimLeaf, VerbatimNode],
     [QuoteLeaf, QuoteNode],
     [TableLeaf, TableNode],
     [CommentOutLeaf, CommentOutNode],
     [HeadingLeaf, HeadingNode],
     [ParagraphLeaf, ParagraphNode],
     [HrLeaf, HrNode],
     [ListLeaf, ListNode],
     [EnumLeaf, EnumNode]
    ].each do |leaf, node|
      ParentNode[leaf] = node
    end

    ParentNode[BlockNodeEnd] = BlockNodeEnd

    def self.assign_head_re
      space = '\s'
      head_pats = []
      [[':', DescLeaf],
       [space, VerbatimLeaf],
       ['""', QuoteLeaf],
       ['||', TableLeaf],
       ['//', CommentOutLeaf],
       ['!', HeadingLeaf],
       ['*', ListLeaf],
       ['#', EnumLeaf]
      ].each do |head, leaf|
        HeadToLeaf[head] = leaf
        escaped_head = head != space ? Regexp.escape(head) : head
        head_pat = leaf.with_depth? ? "(#{escaped_head})+" : "(#{escaped_head})"
        head_pats.push head_pat
        leaf.head_re = Regexp.new('\\A'+head_pat)
      end
      HrLeaf.head_re = Regexp.new(/\A(----)\s*$/o)
      BlockNodeEnd.head_re = Regexp.new(/^(\r?\n?)$/o)
      Regexp.new('\\A('+head_pats.join('|')+')')
    end
    HEAD_RE = assign_head_re

    def initialize
      root_node = BlockNode.new
      def root_node.breakable?(breaker)
        false
      end
      @stack = BlockStack.new(root_node)
    end

    def breakable?(breaker)
      @stack.current_node.breakable?(breaker)
    end

    def select_leaf_type(line)
      [BlockNodeEnd, HrLeaf].each {|leaf| return leaf if leaf.head_re =~ line }
      matched = HEAD_RE.match(line)
      return HeadToLeaf[matched[0]]||HeadToLeaf[line[0,1]] || HeadToLeaf['\s'] if matched
      ParagraphLeaf
    end

    def read_lines(lines)
      while line = lines.shift
        @stack.current_node.add_leaf(line, VerbatimLeaf, self)
      end
      @stack.pop
    end
  end
end
