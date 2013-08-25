#/usr/bin/env ruby

require 'test/unit'
require 'pseudohiki/treestack'

class TC_TreeStack < Test::Unit::TestCase

  def test_push_node
    stack = TreeStack.new
    node = TreeStack::Node.new
    stack.push(node)
    assert_equal([[]],stack.tree)
    second_node = TreeStack::Node.new
    stack.push(second_node)
    assert_equal([[[]]],stack.tree)
  end

  def test_push_leaf
    stack = TreeStack.new
    leaf = TreeStack::Leaf.new
    leaf.push "leaf"
    stack.push(leaf)
    assert_equal([["leaf"]],stack.tree)
    second_leaf = TreeStack::Leaf.new
    second_leaf.push "second_leaf"
    stack.push(second_leaf)
    assert_equal([["leaf"],["second_leaf"]],stack.tree)
  end

  def test_push_leaf_then_node
  end

  def test_without_mergeable
    node = TreeStack::Node.new
    assert_same node.class, TreeStack::Node
    assert_equal true, node.kind_of?(TreeStack::Node)
    assert_not_equal true, node.kind_of?(TreeStack::Mergeable)
  end

  def test_with_mergeable
    node = TreeStack::Node.new
    class <<node #
      include TreeStack::Mergeable
    end
    assert node.kind_of?(TreeStack::Mergeable)
  end

  def test_node_end
    tree = TreeStack.new
    assert tree.node_end.kind_of?(TreeStack::NodeEnd)
  end

  def test_leaf_create
    leaf = TreeStack::Leaf.create("leaf")
    assert_equal(["leaf"],leaf)
    assert_kind_of(TreeStack::Leaf,leaf)
    empty_leaf = TreeStack::Leaf.create
    assert_equal([],empty_leaf)
    assert_kind_of(TreeStack::Leaf,leaf)
  end

  def test_push_as_sibling
    stack = TreeStack.new
    leaf = TreeStack::Leaf.create("leaf")
#    leaf.push "leaf"
    stack.push(leaf)
    assert_equal([["leaf"]],stack.tree)
    node = TreeStack::Node.new
    stack.push(node)
    stack.push(leaf)
    assert_equal([["leaf"],[["leaf"]]],stack.tree)
    subnode = TreeStack::Node.new
    stack.push(subnode)
    stack.push(leaf)
    assert_equal([["leaf"],[["leaf"],[["leaf"]]]],stack.tree)
    sibling_node = TreeStack::Node.new
    stack.push_as_sibling(sibling_node)
    stack.push(leaf)
    assert_equal([["leaf"],[["leaf"],[["leaf"]],[["leaf"]]]],stack.tree)
  end

  def test_depth
    stack = TreeStack.new
    leaf = TreeStack::Leaf.create("leaf")
    leaf2 = TreeStack::Leaf.create("leaf2")
    leaf3 = TreeStack::Leaf.create("leaf2")
    leaf4 = TreeStack::Leaf.create("leaf2")
    node = TreeStack::Node.new
    node2 = TreeStack::Node.new
    assert_nil(leaf.depth)
    stack.push(leaf)
    assert_equal(1,leaf.depth)
    stack.push(leaf2)
    assert_equal(1,leaf2.depth)
    stack.push(node)
    assert_equal(1,node.depth)
    stack.push(leaf3)
    assert_equal(2,leaf3.depth)
    stack.push(node2)
    assert_equal(2,node2.depth)
    stack.push(leaf4)
    assert_equal(3,leaf4.depth)
  end

  def test_last_leaf
    stack = TreeStack.new
    leaf = TreeStack::Leaf.create("leaf")
    node = TreeStack::Node.new
    stack.push(leaf)
    assert_equal(leaf,stack.last_leaf)
    stack.push(node)
    assert_nil(stack.last_leaf)
  end

  def test_node_end
    stack = TreeStack.new
    leaf1 = TreeStack::Leaf.create("leaf1")
    leaf2 = TreeStack::Leaf.create("leaf2")
    leaf3 = TreeStack::Leaf.create("leaf3")
    leaf4 = TreeStack::Leaf.create("leaf4")
    node = TreeStack::Node.new
    node_end = stack.node_end
    stack.push(leaf1)
    stack.push(node)
    stack.push(leaf2)
    stack.push(leaf3)
    assert_equal(["leaf3"],stack.last_leaf)
    stack.push(node_end)
    assert_nil(stack.last_leaf)
    stack.push(leaf4)
    assert_equal([["leaf1"],[["leaf2"],["leaf3"]],["leaf4"]],stack.tree)
  end
end
