#/usr/bin/env ruby

require 'test/unit'
require 'lib/pseudohiki/htmlplugin'

class TC_HtmlPlugin < Test::Unit::TestCase
  include PseudoHiki

  def test_visit_pluginnode
    formatter = HtmlFormat.create_plain
    tree = InlineParser.new("{{co2}} represents the carbon dioxide.").parse.tree
    assert_equal("CO<sub>2</sub> represents the carbon dioxide.",tree.accept(formatter).to_s)
  end
end
