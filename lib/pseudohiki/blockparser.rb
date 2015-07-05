#!/usr/bin/env ruby

require 'pseudohiki/treestack'
require 'pseudohiki/inlineparser'

module PseudoHiki
  class BlockParser
    ID_TAG_PAT = /\A\[([^\[\]]+)\]/o

    VERBATIM_BEGIN = /\A<<<\s*/o
    VERBATIM_END = /\A>>>\s*/o
    PLUGIN_BEGIN = /\{\{/o
    PLUGIN_END = /\}\}/o

    PARENT_NODE = {}

    attr_reader :stack, :auto_linker

    def self.assign_node_id(leaf, node)
#      return unless tree[0].kind_of? Array ** block_leaf:[inline_node:[token or inline_node]]
      head = leaf[0]
      return unless head.kind_of? String
      if m = ID_TAG_PAT.match(head)
        node.node_id = m[1]
        leaf[0] = head.sub(ID_TAG_PAT, "".freeze)
      end
      node
    end

    def self.parse(lines, auto_linker=AutoLink::URL)
      parser = new(auto_linker)
      parser.read_lines(lines)
      parser.stack.tree
    end

    class BlockStack < TreeStack
      def pop
        current_node.parse_leafs
        super
      end
    end

    class BlockLeaf < BlockStack::Leaf
      attr_accessor :level, :node_id

      def self.head_re=(head_regex)
        @self_head_re = head_regex
      end

      def self.head_re
        @self_head_re
      end

      def self.with_depth?
        false
      end

      def self.create(line, inline_parser=InlineParser)
        line = line.sub(head_re, "".freeze) if head_re
        new.concat(inline_parser.parse(line)) # leaf = self.new
      end

      def head_re
        @head_re ||= self.class.head_re
      end

      def block
        @parent_node ||= PARENT_NODE[self.class]
      end

      def push_block(stack)
        stack.push(block.new)
      end

      def under_appropriate_block?(stack)
        stack.current_node.kind_of? block and stack.current_node.level == level
      end

      def push_self(stack)
        push_block(stack) unless under_appropriate_block?(stack)
        super(stack)
      end

      def parse_leafs
        parsed = InlineParser.parse(join)
        clear
        concat(parsed)
      end
    end

    class NonNestedBlockLeaf < BlockLeaf
      include TreeStack::Mergeable

      def self.create(line)
        line = line.sub(head_re, "".freeze) if head_re
        new.tap {|leaf| leaf.push line }
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
      def self.create(line)
        m = head_re.match(line)
        super(line).tap {|leaf| leaf.level = m[0].length }
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
      attr_accessor :node_id

      def level
        first.level if first # @cached_level ||= (first.level if first)
      end

      def push_self(stack)
        @stack = stack
        super(stack)
      end

      def breakable?(breaker)
        not (kind_of? breaker.block and level == breaker.level)
      end

      def parse_leafs; end

      def add_leaf(line, blockparser)
        leaf = create_leaf(line, blockparser)
        blockparser.stack.pop while blockparser.breakable?(leaf)
        blockparser.stack.push leaf
      end

      def create_leaf(line, blockparser)
        return BlockElement::VerbatimLeaf.create("".freeze, true) if VERBATIM_BEGIN =~ line
        line = blockparser.auto_linker.link(line)
        blockparser.select_leaf_type(line).create(line)
      end
    end

    class NonNestedBlockNode < BlockNode
      def parse_leafs
        each {|leaf| leaf.parse_leafs }
      end
    end

    class NestedBlockNode < BlockNode; end

    class ListTypeBlockNode < NestedBlockNode
      def breakable?(breaker)
        not (breaker.block.superclass == ListTypeBlockNode and level <= breaker.level)
      end
    end

    class ListLeafNode < NestedBlockNode
      def breakable?(breaker)
        not (breaker.kind_of? ListTypeLeaf and level < breaker.level)
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
      }.each do |parent_class, sub_classes|
        sub_classes.each {|sub| const_set(sub, Class.new(parent_class)) }
      end

      class BlockNodeEnd
        PARSED_NODE_END = new.concat(InlineParser.parse(""))

        def push_self(stack); end

        def self.create(line, inline_parser=InlineParser)
          PARSED_NODE_END
        end
      end

      class VerbatimNode
        attr_accessor :in_block_tag

        def add_leaf(line, blockparser)
          return @stack.pop if VERBATIM_END =~ line
          return super(line, blockparser) unless @in_block_tag
          line = " #{line}" if BlockNodeEnd.head_re =~ line and not @in_block_tag
          @stack.push VerbatimLeaf.create(line, @in_block_tag)
        end
      end

      class QuoteNode
        def parse_leafs
          self[0] = BlockParser.parse(self[0])
        end
      end

      class HeadingNode
        def breakable?(breaker)
          kind_of? breaker.block and level >= breaker.level
        end
      end

      class VerbatimLeaf
        attr_accessor :in_block_tag

        def self.create(line, in_block_tag=nil)
          line = line.sub(head_re, "".freeze) if head_re and not in_block_tag
          new.tap do |leaf|
            leaf.push line
            leaf.in_block_tag = in_block_tag
          end
        end

        def push_block(stack)
          stack.push(block.new.tap {|n| n.in_block_tag = @in_block_tag })
        end
      end

      class TableLeaf
        def self.create(line)
          super(line, TableRowParser)
        end
      end
    end
    include BlockElement

    class ListTypeLeaf
      include BlockElement

      WRAPPER = {
        ListLeaf => ListWrapNode,
        EnumLeaf => EnumWrapNode
      }

      def push_self(stack)
        push_block(stack) unless under_appropriate_block?(stack)
        stack.push WRAPPER[self.class].new
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
     [EnumLeaf, EnumNode],
     [BlockNodeEnd, BlockNodeEnd] # special case
    ].each do |leaf, node|
      PARENT_NODE[leaf] = node
    end

    head_to_leaf_table = [['\r?\n?$', BlockNodeEnd],
                          ['\s', VerbatimLeaf],
                          ['*', ListLeaf],
                          ['#', EnumLeaf],
                          [':', DescLeaf],
                          ['!', HeadingLeaf],
                          ['""', QuoteLeaf],
                          ['||', TableLeaf],
                          ['//', CommentOutLeaf],
                          ['----\s*$', HrLeaf]]

    IRREGULAR_LEAFS = [:entire_matched_part, BlockNodeEnd, VerbatimLeaf, HrLeaf]
    NUMBER_OF_IRREGULAR_LEAFS = IRREGULAR_LEAFS.length - 1
    HEAD_TO_LEAF = head_to_leaf_table.inject({}) {|h, kv| h[kv[0]] = kv[1]; h }

    def self.assign_head_re(head_to_leaf_table)
      irregular_head_pats, regular_heads = [], []
      head_to_leaf_table.each do |head, leaf|
        leaf_is_irregular = IRREGULAR_LEAFS.include?(leaf)
        escaped_head = leaf_is_irregular ? head : Regexp.escape(head)
        head_pat = leaf.with_depth? ? "#{escaped_head}+" : "#{escaped_head}"
        leaf.head_re = /\A#{head_pat}/
        irregular_head_pats.push "(#{escaped_head})" if leaf_is_irregular
        regular_heads.push head unless leaf_is_irregular
      end
      return /\A(?:#{irregular_head_pats.join('|')})/, regular_heads
    end

    IRREGULAR_HEAD_PAT, REGULAR_HEADS = assign_head_re(head_to_leaf_table)

    def initialize(auto_linker=AutoLink::URL)
      root_node = BlockNode.new
      def root_node.breakable?(breaker)
        false
      end
      @stack = BlockStack.new(root_node)
      @auto_linker = auto_linker
    end

    def breakable?(breaker)
      @stack.current_node.breakable?(breaker)
    end

    def select_leaf_type(line)
      matched = IRREGULAR_HEAD_PAT.match(line)
      1.upto(NUMBER_OF_IRREGULAR_LEAFS) {|i| return IRREGULAR_LEAFS[i] if matched[i] } if matched
      REGULAR_HEADS.each {|head| return HEAD_TO_LEAF[head] if line.start_with?(head) }
      ParagraphLeaf
    end

    def read_lines(lines)
      each_line = lines.respond_to?(:each_line) ? :each_line : :each
      lines.send(each_line) {|line| @stack.current_node.add_leaf(line, self) }
      @stack.pop
    end
  end

  module AutoLink
    # URI_RE is borrowed from hikidoc
    URI_RE = /(?:https?|ftp|file|mailto):[A-Za-z0-9;\/?:@&=+$,\-_.!~*\'()#%]+/
    VERBATIM_LEAF_HEAD_RE = BlockParser::BlockElement::VerbatimLeaf.head_re

    module Off
      def self.link(line) line; end
    end

    module URL
      OPEN_TAG, LINK_SEP = "[[", "|"

      def self.in_link_tag?(preceding_str)
        preceding_str.end_with?(OPEN_TAG) or preceding_str.end_with?(LINK_SEP)
      end

      def self.link(line)
        return line unless URI_RE =~ line and VERBATIM_LEAF_HEAD_RE !~ line
        line.gsub(URI_RE) {|url| in_link_tag?($`) ? url : "[[#{url}]]" }
      end
    end
  end
end
