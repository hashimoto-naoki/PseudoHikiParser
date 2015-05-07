#!/usr/bin/env ruby
require 'minitest/autorun'
require 'pseudohikiparser'

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
end
