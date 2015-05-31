#!/usr/bin/env ruby

require 'pseudohiki/inlineparser'
require 'pseudohiki/blockparser'

module PseudoHiki
  module Utils

    class NodeCollector
      attr_reader :nodes

      def self.select(tree, &condition)
        collector = new(&condition)
        collector.visit(tree)
        collector.nodes
      end

      def initialize(&condition)
        @nodes = []
        @condition = condition
      end

      def visit(tree)
        if @condition.call(tree)
          @nodes.push tree
        else
          tree.each do |node|
            node.accept(self) if node.respond_to? :accept
          end
        end
      end
    end
  end
end
