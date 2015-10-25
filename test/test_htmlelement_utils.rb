#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/htmlelement'
require 'lib/htmlelement/utils'

class TC_HtmlElement < MiniTest::Unit::TestCase
  def setup
    @link_manager = HtmlElement::Utils::LinkManager.new("http://www.example.org/default_path",
                                                        ["stage.example.org", "develop.example.org"])
  end

  def test_link_manager_unify_host_names
    assert_equal("http://www.example.org/path1",
                 @link_manager.unify_host_names("http://stage.example.org/path1"))
    assert_equal("http://www.example.org/path1/path1-1",
                 @link_manager.unify_host_names("http://develop.example.org/path1/path1-1"))
  end

  def test_link_manager_convert_to_relative_path
    assert_equal("../path1", @link_manager.convert_to_relative_path("http://www.example.org/path1"))
    assert_equal("../path1/path1-1/",
                 @link_manager.convert_to_relative_path("http://www.example.org/path1/path1-1/"))
  end
end
