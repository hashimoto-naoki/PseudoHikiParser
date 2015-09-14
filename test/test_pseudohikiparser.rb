#!/usr/bin/env ruby
require 'minitest/autorun'
require 'pseudohikiparser'
require 'pseudohiki/autolink'

class TC_MarkDownFormat < MiniTest::Unit::TestCase
  include PseudoHiki

  def setup
    @text =<<TEXT
!! heading

||!head 1||!head 2
||cell 1||cell 2

the first paragraph with ''inline'' ``tags``

the second paragraph with ==block== [[inline|#id]] tags
TEXT

    @text_with_wikiname = 'a line with WikiName and a [[normal link|http://www.example.org/]]'
  end

  def test_to_html
    expected = <<HTML
<div class="section h2">
<h2> heading
</h2>
<table>
<tr><th>head 1</th><th>head 2
</th></tr>
<tr><td>cell 1</td><td>cell 2
</td></tr>
</table>
<p>
the first paragraph with <em>inline</em> <code>tags</code>
</p>
<p>
the second paragraph with <del>block</del> <a href="#ID">inline</a> tags
</p>
<!-- end of section h2 -->
</div>
HTML
    assert_equal(expected, Format.to_html(@text))
  end

  def test_to_markdown
    expected = <<MD
## heading

<table>
<tr><th>head 1</th><th>head 2</th></tr>
<tr><td>cell 1</td><td>cell 2</td></tr>
</table>

the first paragraph with _inline_ `tags`

the second paragraph with ~~block~~ [inline](#id) tags

MD

    assert_equal(expected, Format.to_markdown(@text))
  end

  def test_to_gfm
    expected = <<MD
## heading

|head 1|head 2|
|------|------|
|cell 1|cell 2|

the first paragraph with _inline_ `tags`

the second paragraph with ~~block~~ [inline](#id) tags

MD

    assert_equal(expected, Format.to_gfm(@text))
  end

  def test_format
    md_expected = <<MD
## heading

<table>
<tr><th>head 1</th><th>head 2</th></tr>
<tr><td>cell 1</td><td>cell 2</td></tr>
</table>

the first paragraph with _inline_ `tags`

the second paragraph with ~~block~~ [inline](#id) tags

MD

    table_text = <<TEXT
||!head 1||!head 2||!head 3
||> cell 1-2||cell 3
TEXT

html_expected = <<HTML
<table>
<tr><th>head 1</th><th>head 2</th><th>head 3</th></tr>
<tr><td colspan="2"> cell 1-2</td><td>cell 3</td></tr>
</table>

HTML

gfm_expected = <<MD
|head 1  |head 2|head 3|
|--------|------|------|
|cell 1-2|      |cell 3|

MD

    assert_equal(md_expected, Format.format(@text, :markdown))
    assert_equal(html_expected, Format.format(table_text, :markdown, :gfm_style => true))
    assert_equal(gfm_expected, Format.format(table_text, :markdown, :gfm_style => :force))
  end

  def test_format_with_block
hiki_table = <<TEXT
||!head 1||!head 2
||cell 1||cell 2
TEXT

expected_html_table = <<HTML
<table id="table">
<tr><th>head 1</th><th>head 2
</th></tr>
<tr><td>cell 1</td><td>cell 2
</td></tr>
</table>
HTML

    table_with_id = Format.to_html(hiki_table) do |html|
      html.traverse do |elm|
        elm["id"] = "table" if elm.kind_of? HtmlElement and elm.tagname == "table"
      end
    end

    assert_equal(expected_html_table, table_with_id)
  end

  def test_format_with_wikiname
    expected_html_with_wikiname = <<HTML
<p>
a line with <a href="WikiName">WikiName</a> and a <a href="http://www.example.org/">normal link</a></p>
HTML

    expected_html_without_wikiname = <<HTML
<p>
a line with WikiName and a <a href="http://www.example.org/">normal link</a></p>
HTML

    assert_equal(expected_html_with_wikiname,
                 Format.format(@text_with_wikiname, :html, nil, AutoLink::WikiName.new))
    assert_equal(expected_html_without_wikiname,
                 Format.format(@text_with_wikiname, :html))

    BlockParser.auto_linker = AutoLink::WikiName.new

    assert_equal(expected_html_with_wikiname,
                 Format.format(@text_with_wikiname, :html))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_without_wikiname,
                 Format.format(@text_with_wikiname, :html))
  end

  def test_format_without_auto_link_in_verbatim
    verbatim_text_with_url = <<TEXT
 a verbatim line with http://www.example.org/ and WikiName
TEXT

    expected_html_without_auto_link_in_verbatim = <<HTML
<pre>
a verbatim line with http://www.example.org/ and WikiName
</pre>
HTML

    assert_equal(expected_html_without_auto_link_in_verbatim,
                 Format.format(verbatim_text_with_url, :html, nil, AutoLink::Off))
  end

  def test_format_with_auto_link_in_verbatim
    verbatim_text_with_url = <<TEXT
 a verbatim line with http://www.example.org/ and WikiName
TEXT

    expected_html_with_auto_link_in_verbatim = <<HTML
<pre>
a verbatim line with <a href="http://www.example.org/">http://www.example.org/</a> and WikiName
</pre>
HTML

    assert_equal(expected_html_with_auto_link_in_verbatim,
                 Format.format(verbatim_text_with_url, :html, nil, AutoLink::URL))
    assert_equal(expected_html_with_auto_link_in_verbatim,
                 Format.format(verbatim_text_with_url, :html, nil, nil))
  end

  def test_to_html_with_wikiname
    wikiname_linker = AutoLink::WikiName.new

    expected_html_with_wikiname = <<HTML
<p>
a line with <a href="WikiName">WikiName</a> and a <a href="http://www.example.org/">normal link</a></p>
HTML

    expected_html_without_wikiname = <<HTML
<p>
a line with WikiName and a <a href="http://www.example.org/">normal link</a></p>
HTML

    assert_equal(expected_html_with_wikiname,
                 Format.to_html(@text_with_wikiname, wikiname_linker))

    assert_equal(expected_html_without_wikiname,
                 Format.to_html(@text_with_wikiname))

    BlockParser.auto_linker = wikiname_linker

    assert_equal(expected_html_with_wikiname,
                 Format.to_html(@text_with_wikiname))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_without_wikiname,
                 Format.to_html(@text_with_wikiname))
  end

  def test_to_xhtml_with_wikiname
    wikiname_linker = AutoLink::WikiName.new

    expected_html_with_wikiname = <<HTML
<p>
a line with <a href="WikiName">WikiName</a> and a <a href="http://www.example.org/">normal link</a></p>
HTML

    expected_html_without_wikiname = <<HTML
<p>
a line with WikiName and a <a href="http://www.example.org/">normal link</a></p>
HTML

    assert_equal(expected_html_with_wikiname,
                 Format.to_xhtml(@text_with_wikiname, wikiname_linker))

    assert_equal(expected_html_without_wikiname,
                 Format.to_xhtml(@text_with_wikiname))

    BlockParser.auto_linker = wikiname_linker

    assert_equal(expected_html_with_wikiname,
                 Format.to_xhtml(@text_with_wikiname))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_without_wikiname,
                 Format.to_xhtml(@text_with_wikiname))
  end

  def test_to_html5_with_wikiname
    wikiname_linker = AutoLink::WikiName.new

    expected_html_with_wikiname = <<HTML
<p>
a line with <a href="WikiName">WikiName</a> and a <a href="http://www.example.org/">normal link</a></p>
HTML

    expected_html_without_wikiname = <<HTML
<p>
a line with WikiName and a <a href="http://www.example.org/">normal link</a></p>
HTML

    assert_equal(expected_html_with_wikiname,
                 Format.to_html5(@text_with_wikiname, wikiname_linker))

    assert_equal(expected_html_without_wikiname,
                 Format.to_html5(@text_with_wikiname))

    BlockParser.auto_linker = wikiname_linker

    assert_equal(expected_html_with_wikiname,
                 Format.to_html5(@text_with_wikiname))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_without_wikiname,
                 Format.to_html5(@text_with_wikiname))
  end

  def test_to_plain_with_wikiname
    wikiname_linker = AutoLink::WikiName.new

    expected_html_with_wikiname = <<HTML
a line with WikiName and a normal link
HTML

    expected_html_without_wikiname = <<HTML
a line with WikiName and a normal link
HTML

    assert_equal(expected_html_with_wikiname,
                 Format.to_plain(@text_with_wikiname, wikiname_linker))

    assert_equal(expected_html_without_wikiname,
                 Format.to_plain(@text_with_wikiname))

    BlockParser.auto_linker = wikiname_linker

    assert_equal(expected_html_with_wikiname,
                 Format.to_plain(@text_with_wikiname))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_without_wikiname,
                 Format.to_plain(@text_with_wikiname))
  end

  def test_to_markdown_with_wikiname
    wikiname_linker = AutoLink::WikiName.new

    expected_html_with_wikiname = <<HTML
a line with [WikiName](WikiName) and a [normal link](http://www.example.org/)
HTML

    expected_html_without_wikiname = <<HTML
a line with WikiName and a [normal link](http://www.example.org/)
HTML

    assert_equal(expected_html_with_wikiname,
                 Format.to_markdown(@text_with_wikiname, wikiname_linker))

    assert_equal(expected_html_without_wikiname,
                 Format.to_markdown(@text_with_wikiname))

    BlockParser.auto_linker = wikiname_linker

    assert_equal(expected_html_with_wikiname,
                 Format.to_markdown(@text_with_wikiname))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_without_wikiname,
                 Format.to_markdown(@text_with_wikiname))
  end

  def test_to_gfm_with_wikiname
    wikiname_linker = AutoLink::WikiName.new

    expected_html_with_wikiname = <<HTML
a line with [WikiName](WikiName) and a [normal link](http://www.example.org/)
HTML

    expected_html_without_wikiname = <<HTML
a line with WikiName and a [normal link](http://www.example.org/)
HTML

    assert_equal(expected_html_with_wikiname,
                 Format.to_gfm(@text_with_wikiname, wikiname_linker))

    assert_equal(expected_html_without_wikiname,
                 Format.to_gfm(@text_with_wikiname))

    BlockParser.auto_linker = wikiname_linker

    assert_equal(expected_html_with_wikiname,
                 Format.to_gfm(@text_with_wikiname))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_without_wikiname,
                 Format.to_gfm(@text_with_wikiname))
  end

  def test_to_html5_without_auto_link
    current_linker = BlockParser.auto_linker

    link_off_linker = AutoLink::Off

    text_with_urls = <<TEXT
a link in a paragraph http://www.example.org/

<<<
http://www.example.org/
>>>
TEXT

    expected_html_with_links = <<HTML
<p>
a link in a paragraph <a href="http://www.example.org/">http://www.example.org/</a>
</p>
<pre>
<a href="http://www.example.org/">http://www.example.org/</a>
</pre>
HTML

    expected_html_without_links = <<HTML
<p>
a link in a paragraph http://www.example.org/
</p>
<pre>
http://www.example.org/
</pre>
HTML

    assert_equal(expected_html_without_links,
                 Format.to_html5(text_with_urls, link_off_linker))

    assert_equal(expected_html_with_links,
                 Format.to_html5(text_with_urls))

    BlockParser.auto_linker = link_off_linker

    assert_equal(expected_html_without_links,
                 Format.to_html5(text_with_urls))

    BlockParser.auto_linker = nil

    assert_equal(expected_html_with_links,
                 Format.to_html5(text_with_urls))

    BlockParser.auto_linker = current_linker
  end
end
