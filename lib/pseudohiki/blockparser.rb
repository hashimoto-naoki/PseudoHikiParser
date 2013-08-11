#!/usr/bin/env ruby

require 'treestack'
require 'pseudohiki/inlineparser'
require 'pseudohiki/htmlformat'

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
        parsed = InlineParser.parse(self.join(""))
        self.clear
        self.concat(parsed)
      end
    end

    class NonNestedBlockLeaf < BlockLeaf
      include TreeStack::Mergeable

      def self.create(line)
        line.sub!(self.head_re,"") if self.head_re
        leaf = self.new
        leaf.push line
        leaf
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
        leaf = super(line)
        leaf.nominal_level = m[0].length
        leaf
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
    end

    class NonNestedBlockNode < BlockNode
      def parse_leafs
        self.each {|leaf| leaf.parse_leafs }
      end
    end

    class NestedBlockNode < BlockNode; end

    class ListTypeBlockNode < NestedBlockNode
      def breakable?(breaker)
        (breaker.block.superclass == ListTypeBlockNode and nominal_level <= breaker.nominal_level) ? false : true
      end
    end

    class ListLeafNode < NestedBlockNode
      def breakable?(breaker)
        (breaker.kind_of?(ListTypeLeaf) and nominal_level < breaker.nominal_level) ? false : true
      end
    end

    module BlockElement
      class DescLeaf < BlockLeaf; end
      class VerbatimLeaf < BlockLeaf; end
      class QuoteLeaf < NonNestedBlockLeaf; end
      class TableLeaf < BlockLeaf; end
      class CommentOutLeaf < BlockLeaf; end
      class HeadingLeaf < NestedBlockLeaf; end
      class ParagraphLeaf < NonNestedBlockLeaf; end
      class HrLeaf < BlockLeaf; end
      class BlockNodeEnd < BlockLeaf; end

      class ListLeaf < ListTypeLeaf; end
      class EnumLeaf < ListTypeLeaf; end

      class DescNode < BlockNode; end
      class VerbatimNode < BlockNode; end
      class QuoteNode < NonNestedBlockNode; end
      class TableNode < BlockNode; end
      class CommentOutNode < BlockNode; end
      class HeadingNode < NestedBlockNode; end
      class ParagraphNode < NonNestedBlockNode; end
      class HrNode < BlockNode; end

      class ListNode < ListTypeBlockNode; end
      class EnumNode < ListTypeBlockNode; end

      class ListWrapNode < ListLeafNode; end
      class EnumWrapNode < ListLeafNode; end
    end
    include BlockElement

    class BlockElement::BlockNodeEnd
      def push_self(stack); end
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
        leaf = self.new
        leaf.push line
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

    def tagfy_link(line)
      line.gsub(URI_RE) do |url|
        unless ($`)[-2,2] == "[[" or ($`)[-1,1] == "|"
          "[[#{url}]]"
        else
          url
        end
      end
    end

    def select_leaf_type(line)
      [BlockNodeEnd, HrLeaf].each {|leaf| return leaf if leaf.head_re =~ line }
      matched = HEAD_RE.match(line)
      return HeadToLeaf[matched[0]]||HeadToLeaf[line[0,1]] || HeadToLeaf['\s'] if matched
      ParagraphLeaf
    end

    def add_verbatim_block(lines)
      until lines.empty? or LINE_PAT::VERBATIM_END =~ lines.first
        lines[0] = " " + lines[0] if BlockNodeEnd.head_re =~ lines.first
        @stack.push(VerbatimLeaf.create(lines.shift))
      end
      lines.shift if LINE_PAT::VERBATIM_END =~ lines.first
    end

    def add_leaf(line)
      leaf = select_leaf_type(line).create(line)
      while breakable?(leaf)
        @stack.pop
      end
      @stack.push leaf
    end

    def read_lines(lines)
      while line = lines.shift
        if LINE_PAT::VERBATIM_BEGIN =~ line
          add_verbatim_block(lines)
        else
          line = self.tagfy_link(line) unless VerbatimLeaf.head_re =~ line
          add_leaf(line)
        end
      end
      @stack.pop
    end

    def self.parse(lines)
      parser = self.new
      parser.read_lines(lines)
      parser.stack.tree
    end
  end
end

module PseudoHiki
  class HtmlFormat
    include BlockParser::BlockElement
    include TableRowParser::InlineElement

    DESC, VERB, QUOTE, TABLE, PARA, HR, UL, OL = %w(dl pre blockquote table p hr ul ol)
    SECTION = "section"
    DT, DD, TR, HEADING, LI = %w(dt dd tr h li)
    DescSep = [InlineParser::DescSep]

    class VerbatimNodeFormatter < self
      def visit(tree)
        create_self_element.configure do |element|
          contents = @generator.escape(tree.join).gsub(BlockParser::URI_RE) do |url|
            create_element("a", url, "href" => url).to_s
          end
          element.push contents
        end
      end
    end

    class CommentOutNodeFormatter < self
      def visit(tree); ""; end
    end

    class HeadingNodeFormatter < self
      def create_self_element(tree)
        super(tree).configure do |element|
          heading_level = "h#{tree.first.nominal_level}"
          element['class'] ||= heading_level
          element['class'] +=  " " + heading_level unless element['class'] == heading_level
        end
      end
    end

    class DescLeafFormatter < self
      def visit(tree)
        tree = tree.dup
        dt = create_self_element(tree)
        dd = create_element(DD)
        element = @generator::Children.new
        element.push dt
        dt_sep_index = tree.index(DescSep)
        if dt_sep_index
          tree.shift(dt_sep_index).each do |token|
            dt.push visited_result(token)
          end
          tree.shift
          unless tree.empty?
            tree.each {|token| dd.push visited_result(token) }
            element.push dd
          end
        else
          tree.each {|token| dt.push visited_result(token) }
        end
        element
      end
    end

    class TableCellNodeFormatter < self
      def visit(tree)
        @element_name = tree.cell_type
        create_self_element.configure do |element|
          element["rowspan"] = tree.rowspan if tree.rowspan > 1
          element["colspan"] = tree.colspan if tree.colspan > 1
          tree.each {|token| element.push visited_result(token) }
        end
      end
    end

    class HeadingLeafFormatter < self
      def create_self_element(tree)
        create_element(@element_name+tree.nominal_level.to_s).configure do |element|
          element["id"] = tree.node_id.upcase if tree.node_id
        end
      end
    end

    class ListLeafNodeFormatter < self
      def create_self_element(tree)
        super(tree).configure do |element|
          element["id"] = tree.node_id.upcase if tree.node_id
        end
      end
    end

    [[DescNode, DESC],
#     [VerbatimNode, VERB],
     [QuoteNode, QUOTE],
     [TableNode, TABLE],
#     [CommentOutNode, nil],
#     [HeadingNode, SECTION],
     [ParagraphNode, PARA],
     [HrNode, HR],
     [ListNode, UL],
     [EnumNode, OL],
#     [DescLeaf, DT],
     [TableLeaf, TR],
#     [HeadingLeaf, HEADING],
#     [ListLeaf, LI],
#     [EnumLeaf, LI],
#     [ListWrapNode, LI],
#     [EnumWrapNode, LI]
    ].each {|node_class, element| Formatter[node_class] = self.new(element) }

    Formatter[VerbatimNode] = VerbatimNodeFormatter.new(VERB)
    Formatter[CommentOutNode] = CommentOutNodeFormatter.new(nil)
    Formatter[HeadingNode] = HeadingNodeFormatter.new(SECTION)
    Formatter[DescLeaf] = DescLeafFormatter.new(DT)
    Formatter[TableCellNode] = TableCellNodeFormatter.new(nil)
    Formatter[HeadingLeaf] = HeadingLeafFormatter.new(HEADING)
    Formatter[ListWrapNode] = ListLeafNodeFormatter.new(LI)
    Formatter[EnumWrapNode] = ListLeafNodeFormatter.new(LI)

    class << Formatter[DescNode]
    end

    class << Formatter[QuoteNode]
    end

    class << Formatter[TableNode]
    end

    class << Formatter[ParagraphNode]
    end

    class << Formatter[HrNode]
    end

    class << Formatter[ListNode]
    end

    class << Formatter[EnumNode]
    end

    class << Formatter[ListLeaf]
    end

    class << Formatter[EnumLeaf]
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
