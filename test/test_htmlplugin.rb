#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/pseudohiki/htmlplugin'

class TC_HtmlPlugin < MiniTest::Unit::TestCase
  include PseudoHiki

  def test_visit_pluginnode
    formatter = HtmlFormat.get_plain
    tree = InlineParser.new("{{co2}} represents the carbon dioxide.").parse.tree
    assert_equal("CO<sub>2</sub> represents the carbon dioxide.",tree.accept(formatter).to_s)
  end

  def test_escape_inline_tags
    formatter = HtmlFormat.get_plain
    tree = InlineParser.new("a line with an inline tag such as {{''}}").parse.tree
    assert_equal("a line with an inline tag such as ''",tree.accept(formatter).to_s)
  end
end
