#!/usr/bin/env ruby

class TreeStack

  class NotLeafError < Exception; end

  module Mergeable; end

# a class that includes NodeType is expected to have #push method to include child nodes,
# and a class that includes LeafType module is expected to have #concat method.

  module TreeElement
    attr_accessor :depth

    def accept(visitor)
      visitor.visit(self)
    end
  end

  module NodeType
    def push_self(stack)
      @depth = stack.current_depth + 1
      stack.push_as_child_node self
      nil
    end
  end

  module LeafType
    def push_self(stack)
      @depth = stack.current_depth + 1
      stack.push_as_leaf self
      self
    end

    def merge(leaf)
      raise NotLeafError unless leaf.kind_of? Leaf
      return nil unless leaf.kind_of? Mergeable
      self.concat(leaf)
    end
  end

  class Node < Array
    include TreeElement
    include NodeType
  end

  class Leaf < Array
    include TreeElement
    include LeafType

    def self.create(content=nil)
      leaf = self.new
      leaf.push content if content
      leaf
    end
  end

  class NodeEnd
    def push_self(stack)
      stack.pop
      nil
    end
  end
  attr_reader :node_end, :last_leaf

  def initialize(root_node=Node.new)
    @stack = [root_node]
    @node_end = NodeEnd.new
    def root_node.depth
      0
    end
  end

  def current_node
    @stack.last
  end

  def tree
    @stack[0]
  end

  def push(node=Node.new)
    @last_leaf = node.push_self(self)
    node
  end

  def pop
    @stack.pop if @stack.length > 1
  end
  alias return_to_previous_node pop

  def current_depth
    @stack.last.depth
  end

  def push_as_child_node(node)
    @stack.last.push node
    @stack.push node
  end
  
  def push_as_leaf(node)
    @stack.last.push node
  end

  def push_as_sibling(sibling_node=nil)
    sibling_node ||= current_node.class.new
    pop if sibling_node.kind_of? NodeType
    push(sibling_node)
    sibling_node
  end

  def remove_current_node
    removed_node = self.pop
    self.current_node.pop
    removed_node
  end

  def accept(visitor)
    visitor.visit(tree)
  end
end
