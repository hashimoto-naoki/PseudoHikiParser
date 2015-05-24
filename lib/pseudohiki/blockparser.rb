#!/usr/bin/env ruby

require 'pseudohiki/treestack'
require 'pseudohiki/inlineparser'

module PseudoHiki
  class BlockParser
    URI_RE = /(?:(?:https?|ftp|file):|mailto:)[A-Za-z0-9;\/?:@&=+$,\-_.!~*\'()#%]+/ #borrowed from hikidoc
    ID_TAG_PAT = /\A\[([^\[\]]+)\]/o

    module LINE_PAT
      VERBATIM_BEGIN = /\A<<<\s*/o
      VERBATIM_END = /\A>>>\s*/o
      PLUGIN_BEGIN = /\{\{/o
      PLUGIN_END = /\}\}/o
    end

    ParentNode = {}

    attr_reader :stack

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

    def self.parse(lines)
      parser = self.new
      parser.read_lines(lines)
      parser.stack.tree
    end

    class BlockStack < TreeStack
      attr_reader :stack

      def pop_with_breaker(breaker=nil)
        self.current_node.parse_leafs(breaker)
        pop
      end
    end

    class BlockLeaf < BlockStack::Leaf
      attr_accessor :nominal_level, :node_id, :decorator

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
        line = line.sub(self.head_re, "".freeze) if self.head_re
        new.concat(inline_parser.parse(line)) #leaf = self.new
      end

      def head_re
        @head_re ||= self.class.head_re
      end

      def block
        @parent_node ||= ParentNode[self.class]
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

      def parse_leafs(breaker)
        parsed = InlineParser.parse(self.join)
        self.clear
        self.concat(parsed)
      end
    end

    class NonNestedBlockLeaf < BlockLeaf
      include TreeStack::Mergeable

      def self.create(line)
        line = line.sub(self.head_re, "".freeze) if self.head_re
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
      attr_accessor :node_id

      def nominal_level
        first.nominal_level if first # @cached_nominal_level ||= (first.nominal_level if first)
      end

      def decorator
        first.decorator if first
      end

      def push_self(stack)
        @stack = stack
        super(stack)
      end

      def breakable?(breaker)
        not (kind_of?(breaker.block) and nominal_level == breaker.nominal_level)
      end

      def parse_leafs(breaker); end

      def in_link_tag?(preceding_str)
        preceding_str[-2, 2] == "[[".freeze or preceding_str[-1, 1] == "|".freeze
      end

      def tagfy_link(line)
        line.gsub(URI_RE) {|url| in_link_tag?($`) ? url : "[[#{url}]]" }
      end

      def add_leaf(line, blockparser)
        leaf = create_leaf(line, blockparser)
        blockparser.stack.pop_with_breaker(leaf) while blockparser.breakable?(leaf)
        blockparser.stack.push leaf
      end

      def create_leaf(line, blockparser)
        return BlockElement::VerbatimLeaf.create("".freeze, true) if LINE_PAT::VERBATIM_BEGIN =~ line
        line = tagfy_link(line) if URI_RE =~ line and BlockElement::VerbatimLeaf.head_re !~ line
        blockparser.select_leaf_type(line).create(line)
      end
    end

    class NonNestedBlockNode < BlockNode
      def parse_leafs(breaker)
        self.each {|leaf| leaf.parse_leafs(breaker) }
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
        BlockLeaf => %w(DescLeaf VerbatimLeaf TableLeaf CommentOutLeaf BlockNodeEnd HrLeaf DecoratorLeaf SectioningNodeEnd),
        NonNestedBlockLeaf => %w(QuoteLeaf ParagraphLeaf),
        NestedBlockLeaf => %w(HeadingLeaf),
        ListTypeLeaf => %w(ListLeaf EnumLeaf),
        BlockNode => %w(DescNode VerbatimNode TableNode CommentOutNode HrNode DecoratorNode SectioningNode),
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
      PARSED_NODE_END = new.concat(InlineParser.parse(""))

      def push_self(stack); end

      def self.create(line, inline_parser=InlineParser)
        PARSED_NODE_END
      end
    end

    class BlockElement::VerbatimNode
      attr_accessor :in_block_tag

      def add_leaf(line, blockparser)
        return @stack.pop_with_breaker if LINE_PAT::VERBATIM_END =~ line
        return super(line, blockparser) unless @in_block_tag
        line = " ".concat(line) if BlockElement::BlockNodeEnd.head_re =~ line and not @in_block_tag
        @stack.push BlockElement::VerbatimLeaf.create(line, @in_block_tag)
      end
    end

    class BlockElement::DecoratorNode
      DECORATOR_PAT = /\A(?:([^\[\]:]+))?(?:\[([^\[\]]+)\])?(?::\s*(\S.*))?/o

      class DecoratorItem < Struct.new(:string, :type, :id, :value)
        def initialize(*args)
          super
          self.value = InlineParser.parse(self.value) if self.value
        end
      end

      def parse_leafs(breaker)
        decorator = {}
        breaker.decorator = decorator
        @stack.remove_current_node.each do |leaf|
          m = DECORATOR_PAT.match(leaf.join)
          return nil unless m
          item = DecoratorItem.new(*(m.to_a))
          decorator[item.type||:id] = item
        end
      end

      def breakable?(breaker)
        return super if breaker.kind_of?(BlockElement::DecoratorLeaf)
        parse_leafs(breaker)
        @stack.current_node.breakable?(breaker)
      end
    end

    class BlockElement::DecoratorLeaf
      def push_sectioning_node(stack, node_class)
        node = node_class.new
        m = BlockElement::DecoratorNode::DECORATOR_PAT.match(self.join)
        node.node_id = m[2]
        stack.push(node)
      end

      def push_self(stack)
        decorator_type = self[0][0]
        if decorator_type.start_with? "begin[".freeze
          push_sectioning_node(stack, BlockElement::SectioningNode)
        elsif decorator_type.start_with? "end[".freeze
          push_sectioning_node(stack, BlockElement::SectioningNodeEnd)
        else
          super
        end
      end
    end

    class BlockElement::SectioningNode
      def breakable?(breaker)
        false
      end
    end

    class BlockElement::SectioningNodeEnd
      def push_self(stack)
        n = stack.stack.rindex do |node|
          node.kind_of? BlockElement::SectioningNode and node.node_id == self.node_id
        end
        if n
          stack.pop until stack.stack.length == n
        end
      end
    end

    class BlockElement::QuoteNode
      def parse_leafs(breaker)
        self[0] = BlockParser.parse(self[0])
      end
    end

    class BlockElement::HeadingNode
      def breakable?(breaker)
        kind_of?(breaker.block) and nominal_level >= breaker.nominal_level
      end
    end

    class BlockElement::VerbatimLeaf
      attr_accessor :in_block_tag

      def self.create(line, in_block_tag=nil)
        line = line.sub(self.head_re, "".freeze) if self.head_re and not in_block_tag
        self.new.tap do |leaf|
          leaf.push line
          leaf.in_block_tag = in_block_tag
        end
      end

      def push_block(stack)
        stack.push(block.new.tap {|n| n.in_block_tag = @in_block_tag })
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
     [EnumLeaf, EnumNode],
     [DecoratorLeaf, DecoratorNode]
    ].each do |leaf, node|
      ParentNode[leaf] = node
    end

    ParentNode[BlockNodeEnd] = BlockNodeEnd

    def self.assign_head_re
      irregular_leafs = [BlockNodeEnd, VerbatimLeaf, HrLeaf]
      irregular_head_pats, regular_leaf_types, head_to_leaf = [], [], {}
      [['\r?\n?$', BlockNodeEnd],
       ['\s', VerbatimLeaf],
       ['*', ListLeaf],
       ['#', EnumLeaf],
       [':', DescLeaf],
       ['!', HeadingLeaf],
       ['""', QuoteLeaf],
       ['||', TableLeaf],
       ['//@', DecoratorLeaf],
       ['//', CommentOutLeaf],
       ['----\s*$', HrLeaf]
      ].each do |head, leaf|
        escaped_head = irregular_leafs.include?(leaf) ? head : Regexp.escape(head)
        head_pat = leaf.with_depth? ? "#{escaped_head}+" : "#{escaped_head}"
        leaf.head_re = Regexp.new('\\A'+head_pat)
        head_to_leaf[head] = leaf
        irregular_head_pats.push "(#{escaped_head})" if irregular_leafs.include?(leaf)
        regular_leaf_types.push head unless irregular_leafs.include?(leaf)
      end
      irregular_leaf_types = [:entire_matched_part].concat(irregular_leafs)
      return Regexp.new('\\A(?:'+irregular_head_pats.join('|')+')'), regular_leaf_types, head_to_leaf, irregular_leaf_types, irregular_leafs.length
    end

    IRREGULAR_HEAD_PAT, REGULAR_LEAF_TYPES, HEAD_TO_LEAF, IRREGULAR_LEAF_TYPES, NUMBER_OF_IRREGULAR_LEAF_TYPES = assign_head_re

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
      matched = IRREGULAR_HEAD_PAT.match(line)
      1.upto(NUMBER_OF_IRREGULAR_LEAF_TYPES) {|i| return IRREGULAR_LEAF_TYPES[i] if matched[i] } if matched
      REGULAR_LEAF_TYPES.each {|head| return HEAD_TO_LEAF[head] if line.start_with?(head) }
      ParagraphLeaf
    end

    def read_lines(lines)
      each_line = lines.respond_to?(:each_line) ? :each_line : :each
      lines.send(each_line) {|line| @stack.current_node.add_leaf(line, self) }
      @stack.pop_with_breaker
    end
  end
end
