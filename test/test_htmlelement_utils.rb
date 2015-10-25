#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/htmlelement'
require 'lib/htmlelement/utils'

class TC_HtmlElement < MiniTest::Unit::TestCase
  def setup
    @link_manager = HtmlElement::Utils::LinkManager.new("http://www.example.org",
                                                        "default_path",
                                                        ["stage.example.org", "develop.example.org"])
  end

  def test_link_manager_unify_domain_names
    assert(@link_manager.unify_domain_names("http://stage.example.org/path1"), "Not implemented yet")
  end

  def test_link_manager_convert_in_relative
    assert(@link_manager.convert_in_relative("http://stage.example.org/path2"), "Not implemented yet")
  end
end
