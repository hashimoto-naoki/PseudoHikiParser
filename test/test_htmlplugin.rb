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

  def test_html_plugin
    formatter = HtmlFormat.get_plain
    tree = InlineParser.new("you can directly embed a snippet of html code like '{{html(<i>italic</i>)}}'.").parse.tree
    assert_equal("you can directly embed a snippet of html code like '<i>italic</i>'.",tree.accept(formatter).to_s)
  end

  def test_html
    expected_html = '<ul>
<li>list
<li>list
</ul>'

    input = "html(
<ul>
<li>list
<li>list
</ul>)"

    assert_equal(expected_html, HtmlPlugin.new("div", input).apply)
  end

  def test_inline
    input = "inline(
*list
*list
)"

    assert_raises(ArgumentError) do
      HtmlPlugin.new("div", input).apply
    end
  end

  def test_co2
    assert_equal("CO<sub>2</sub>", HtmlPlugin.new("div", "co2").apply)
    assert_equal("carbon dioxide", HtmlPlugin.new("div", "co2 :en").apply)
  end

  def test_cubic
    assert_equal("3km<sup>3</sup>", HtmlPlugin.new("div", "cb(3km)").apply)
  end

  def test_per
    assert_equal("m<sup>-1</sup>", HtmlPlugin.new("div", "per m").apply)
  end

  def test_co2_isotope
    assert_equal("<sup>18</sup>CO<sub>2</sub>", HtmlPlugin.new("div", "iso 18co2").apply)
  end
end
