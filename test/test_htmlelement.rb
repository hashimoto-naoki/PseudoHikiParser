#/usr/bin/env ruby

require 'test/unit'
require 'lib/htmlelement'

class TC_HtmlElement < Test::Unit::TestCase

  def test_format_attributes
    a = HtmlElement.create("a")
    a['href'] = "http://www.example.net/example.cgi&param=value"
    assert_equal('<a href="http://www.example.net/example.cgi&amp;param=value"></a>', a.to_s)
  end
end
