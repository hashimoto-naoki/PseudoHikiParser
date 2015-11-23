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
    @link_manager_without_from_host_names = HtmlElement::Utils::LinkManager.new("www.example.org/default_path")
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

  def test_unify_host_names_without_from_host_names
    assert_equal("http://stage.example.org/path1",
                 @link_manager_without_from_host_names.unify_host_names("http://stage.example.org/path1"))
    assert_equal("http://develop.example.org/path1/path1-1",
                 @link_manager_without_from_host_names.unify_host_names("http://develop.example.org/path1/path1-1"))
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

class TC_HtmlElement_Utils_TableManager < MiniTest::Unit::TestCase
  def setup
    table_with_row_header_text = <<TABLE
||!header1||!header2||!header3
||row1-1||row1-2||row1-3
||row2-1||row2-2||row2-3
TABLE

table_with_col_header_text = <<TABLE
||!header1||col1-1||col2-1
||!header2||col1-2||col2-2
||!header3||col1-3||col2-3
TABLE

    @table_manager = HtmlElement::Utils::TableManager.new
    @table_with_row_header = PseudoHiki::BlockParser.parse(table_with_row_header_text)
    @table_with_col_header = PseudoHiki::BlockParser.parse(table_with_col_header_text)

  end

  def test_determine_header_scope
    html_table = PseudoHiki::HtmlFormat.format(@table_with_row_header)[0]
    assert_equal("col", @table_manager.determine_header_scope(html_table))

    html_table = PseudoHiki::HtmlFormat.format(@table_with_col_header)[0]
    assert_equal("row", @table_manager.determine_header_scope(html_table))
  end

  def test_assign_scope
col_scope_table = <<TABLE
<table>
<tr><th scope="col">header1</th><th scope="col">header2</th><th scope="col">header3
</th></tr>
<tr><td>row1-1</td><td>row1-2</td><td>row1-3
</td></tr>
<tr><td>row2-1</td><td>row2-2</td><td>row2-3
</td></tr>
</table>
TABLE

row_scope_table = <<TABLE
<table>
<tr><th scope="row">header1</th><td>col1-1</td><td>col2-1
</td></tr>
<tr><th scope="row">header2</th><td>col1-2</td><td>col2-2
</td></tr>
<tr><th scope="row">header3</th><td>col1-3</td><td>col2-3
</td></tr>
</table>
TABLE

    html_table = PseudoHiki::HtmlFormat.format(@table_with_row_header)[0]
    @table_manager.assign_scope(html_table)
    assert_equal(col_scope_table, html_table.to_s)

    html_table = PseudoHiki::HtmlFormat.format(@table_with_col_header)[0]
    @table_manager.assign_scope(html_table)
    assert_equal(row_scope_table, html_table.to_s)
  end
end
