#!/usr/bin/env ruby



NODES = %w(PlainNode InlineNode InlineLeaf LinkNode EmNode StrongNode DelNode PluginNode DescLeaf TableCellNode VerbatimLeaf QuoteLeaf TableLeaf CommentOutLeaf HeadingLeaf ParagraphLeaf HrLeaf BlockNodeEnd ListLeaf EnumLeaf DescNode VerbatimNode QuoteNode TableNode CommentOutNode HeadingNode ParagraphNode HrNode ListNode EnumNode ListWrapNode EnumWrapNode)

SUB_VISITOR_TEMPLATE = <<TEMPLATE
#    class %1$sFormatter < self; end
TEMPLATE

SUB_VISITOR_INSTANCE_GENERATION_TEMPLATE =<<TEMPLATE
#      formatter[%1$s] = %1$sFormatter.new(formatter, options)
TEMPLATE

MAIN_VISTOR_TEMPLATE =<<TEMPLATE
#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'

module PseudoHiki
  class %1$sFormat
    include InlineParser::InlineElement
    include TableRowParser::InlineElement
    include BlockParser::BlockElement

    def initialize(formatter={}, options=nil)
      @formatter = formatter
      @options = options
    end

    def create_self_element(tree=nil)
    end

    def visited_result(node)
      visitor = @formatter[node.class]||@formatter[PlainNode]
      node.accept(visitor)
    end

    def visit(tree)
      element = create_self_element(tree)
      tree.each do |node|
        visited_result(node)
      end
      element
    end

    def get_plain
      @formatter[PlainNode]
    end
    
    def format(tree)
      formatter = self.get_plain
      tree.accept(formatter)
    end

    def self.create(options)
      formatter = {}
      main_formatter = self.new(formatter, options)
      formatter.default = main_formatter


%2$s
      main_formatter
    end

## Definitions of subclasses of %1$sFormat begins here.

%3$s
  end
end
TEMPLATE

def generate_template(visitor_class_name)
  generic_instances = []
  sub_visitor_instances = ""
  sub_visitors = ""
  NODES.each do |node_name|
    generic_instances.push "       #{node_name}"
    sub_visitor_instances.concat(SUB_VISITOR_INSTANCE_GENERATION_TEMPLATE%[node_name])
    sub_visitors.concat(SUB_VISITOR_TEMPLATE%[node_name])
  end
  MAIN_VISTOR_TEMPLATE%[visitor_class_name,
                        sub_visitor_instances,
                        sub_visitors]
end

if __FILE__ == $0
  puts generate_template(ARGV[0])
end

module PseudoHiki
  class Format
    def self.create
      [
      ].each do |node_class|
        formatter[node_class] = self.new(formatter, options)
      end
    end
  end
end
