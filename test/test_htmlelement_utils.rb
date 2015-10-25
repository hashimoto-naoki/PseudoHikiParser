#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/htmlelement'
require 'lib/htmlelement/utils'
require 'pseudohikiparser'

class TC_HtmlElement_Utils_LinkManager < MiniTest::Unit::TestCase
  def setup
    @default_domain = "http://www.example.org/default_path"
    @link_manager = HtmlElement::Utils::LinkManager.new(@default_domain,
                                                        ["stage.example.org", "develop.example.org"])
  end

  def test_unify_host_names
    assert_equal("http://www.example.org/path1",
                 @link_manager.unify_host_names("http://stage.example.org/path1"))
    assert_equal("http://www.example.org/path1/path1-1",
                 @link_manager.unify_host_names("http://develop.example.org/path1/path1-1"))
  end

  def test_convert_to_relative_path
    assert_equal("../path1", @link_manager.convert_to_relative_path("http://www.example.org/path1"))
    assert_equal("../path1/path1-1/",
                 @link_manager.convert_to_relative_path("http://www.example.org/path1/path1-1/"))
    assert_equal("./",
                 @link_manager.convert_to_relative_path(@default_domain + "/"))
    assert_equal("./",
                 @link_manager.convert_to_relative_path(@default_domain))
  end
end
