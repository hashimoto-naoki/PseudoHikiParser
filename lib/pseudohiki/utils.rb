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

    class TableManager
      TH, COL, ROW = %w(th col row)

      def guess_header_scope(table)
        col_scope?(table) or row_scope?(table)
      end

      private

      def col_scope?(table)
        table.each_with_index do |row, i|
          row.each do |cell|
            return if cell.rowspan > 1 or cell.colspan > 1
            # The first row sould be consist of <th> elements
            # and other rows should not include <th> elements
            return unless (i == 0) == (cell.cell_type == TH)
          end
        end
        COL
      end

      def row_scope?(table)
        table.each do |row|
          row.each_with_index do |cell, j|
            return if cell.rowspan > 1 or cell.colspan > 1
            # The first column sould be consist of <th> elements
            # and other columns should not include <th> elements
            return unless (j == 0) == (cell.cell_type == TH)
          end
        end
        ROW
      end
    end
  end
end
