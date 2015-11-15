#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/htmlelement'
require 'lib/htmlelement/utils'
require 'pseudohikiparser'

class TC_HtmlElement_Utils_LinkManager < MiniTest::Unit::TestCase
  def setup
    @default_domain = "http://www.example.org/default_path"
    @from_host_names = ["stage.example.org", "develop.example.org"]
    @link_manager = HtmlElement::Utils::LinkManager.new(@default_domain,
                                                        @from_host_names)
    @link_manager_without_scheme = HtmlElement::Utils::LinkManager.new("www.example.org/default_path",
                                                                       @from_host_names)
  end

  def test_unify_host_names
    assert_equal("http://www.example.org/path1",
                 @link_manager.unify_host_names("http://stage.example.org/path1"))
    assert_equal("http://www.example.org/path1/path1-1",
                 @link_manager.unify_host_names("http://develop.example.org/path1/path1-1"))
  end

  def test_unify_host_names_without_scheme
    assert_equal("http://www.example.org/path1",
                 @link_manager_without_scheme.unify_host_names("http://stage.example.org/path1"))
    assert_equal("http://www.example.org/path1/path1-1",
                 @link_manager_without_scheme.unify_host_names("http://develop.example.org/path1/path1-1"))
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

  def test_external_link?
    assert(@link_manager.external_link?("http://www.example.com"), "In a different domain")
    refute(@link_manager.external_link?("https://www.example.org/path2"), "In the same domain")
  end

  def test_collect_links
    hiki_text = <<TEXT
!! Sample data with links

*[[Default path|http://www.example.org/default_path/]]
*[[Default index|http://www.example.org/default_path/index.html]]
*[[Path for staging server|http://stage.example.org/path1/path1-1/index.html]]
TEXT

    expected_html = <<HTML
<div class="section h2">
<h2> Sample data with links
</h2>
<ul>
<li><a href="./">Default path</a>
</li>
<li><a href="index.html">Default index</a>
</li>
<li><a href="../path1/path1-1/index.html">Path for staging server</a>
</li>
</ul>
<!-- end of section h2 -->
</div>
HTML

    html_str = PseudoHiki::Format.to_xhtml(hiki_text) do |html|
      links = HtmlElement::Utils::LinkManager.collect_links(html)
      links.each do |a|
        href = a["href"]
        href = @link_manager.unify_host_names(href)
        href = @link_manager.convert_to_relative_path(href)
        a["href"] = href
      end
    end

    assert_equal(expected_html, html_str)
  end

  def test_use_relative_path_for_in_domain_links
    hiki_text = <<TEXT
!! Sample data with links

*[[Default path|http://www.example.org/default_path/]]
*[[Default index|http://www.example.org/default_path/index.html]]
*[[Path for staging server|http://stage.example.org/path1/path1-1/index.html]]
TEXT

    expected_html = <<HTML
<div class="section h2">
<h2> Sample data with links
</h2>
<ul>
<li><a href="./">Default path</a>
</li>
<li><a href="index.html">Default index</a>
</li>
<li><a href="../path1/path1-1/index.html">Path for staging server</a>
</li>
</ul>
<!-- end of section h2 -->
</div>
HTML

    html_str = PseudoHiki::Format.to_xhtml(hiki_text) do |html|
      @link_manager.use_relative_path_for_in_domain_links(html).to_s
    end

    assert_equal(expected_html, html_str)
  end
end
