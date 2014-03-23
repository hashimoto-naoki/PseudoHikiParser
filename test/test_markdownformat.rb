#!/usr/bin/env ruby

require 'minitest/autorun'
require 'pseudohiki/markdownformat'

class TC_MarkDownFormat < MiniTest::Unit::TestCase
  include PseudoHiki

  def setup
    @formatter = MarkDownFormat.create
    @gfm_formatter = MarkDownFormat.create({ :gfm_style => true })
    @forced_gfm_formatter = MarkDownFormat.create({ :gfm_style => :force })
  end

  def test_self_format
    text = <<TEXT
||!header 1||!header 2
||cell 1-1||cell 1-2
||cell 2-1||cell 2-2
||cell 3-1 (a bit wider)||cell 3-2
TEXT

    md_text = <<TEXT
<table>
<tr><th>header 1</th><th>header 2</th></tr>
<tr><td>cell 1-1</td><td>cell 1-2</td></tr>
<tr><td>cell 2-1</td><td>cell 2-2</td></tr>
<tr><td>cell 3-1 (a bit wider)</td><td>cell 3-2</td></tr>
</table>

TEXT

    gfm_text = <<TEXT
|header 1              |header 2|
|----------------------|--------|
|cell 1-1              |cell 1-2|
|cell 2-1              |cell 2-2|
|cell 3-1 (a bit wider)|cell 3-2|

TEXT

    tree = BlockParser.parse(text)
    assert_equal(md_text, MarkDownFormat.format(tree))
    assert_equal(gfm_text, MarkDownFormat.format(tree, :gfm_style => true))
  end

  def test_plain
    text = <<TEXT
test string
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("test string\n#{$/}", @formatter.format(tree).to_s)
  end

  def test_link_url
    text = <<TEXT
A test string with a [[link|http://www.example.org/]] is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with a [link](http://www.example.org/) is here.\n#{$/}", @formatter.format(tree).to_s)
  end

  def test_link_image
    image = <<IMAGE
A test for a link to [[an image|image.png]]
IMAGE
    tree = BlockParser.parse(image.lines.to_a)
    assert_equal("A test for a link to ![an image](image.png)\n#{$/}", @formatter.format(tree).to_s)
  end

  def test_em
    text = "string with ''emphasis'' "
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("string with _emphasis_ #{$/}", @formatter.format(tree).to_s)
  end

  def test_strong
    text = "string with '''emphasis''' "
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("string with **emphasis** #{$/}", @formatter.format(tree).to_s)
  end

  def test_del
    text = "a ==striked out string=="
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("a ~~striked out string~~#{$/}", @formatter.format(tree).to_s)
  end

  def test_literal
    text = "a ``literal`` word"
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("a `literal` word#{$/}", @formatter.format(tree).to_s)
  end

  def test_plugin
    text = <<TEXT
A paragraph with several plugin tags.
{{''}} should be presented as two quotation marks.
{{ {}} should be presented as two left curly braces.
{{} }} should be presented as two right curly braces.
{{in span}} should be presented as 'in span'.
TEXT
    expected_text = <<TEXT
A paragraph with several plugin tags.
'' should be presented as two quotation marks.
{{ should be presented as two left curly braces.
}} should be presented as two right curly braces.
in span should be presented as 'in span'.

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, @formatter.format(tree).to_s)
  end

  def test_hr
    text = "----#{$/}"
    md_text = "----#{$/}"
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_desc
    text = <<TEXT
:word 1:description of word 1
:word 2:description of word 2
TEXT

    html = <<HTML
<dl>
<dt>word 1</dt>
<dd>description of word 1</dd>
<dt>word 2</dt>
<dd>description of word 2</dd>
</dl>

HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(html, @formatter.format(tree).to_s)
  end

  def test_verbatim
    text = <<TEXT
 verbatim ''line'' 1
 verbatim line 2
TEXT

    gfm_text =<<TEXT
```
verbatim ''line'' 1
verbatim line 2
```

TEXT

    md_text = <<TEXT
    verbatim ''line'' 1
    verbatim line 2

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(gfm_text, @gfm_formatter.format(tree).to_s)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_comment_out
    text = <<TEXT
a line
//a comment
TEXT

    md_text = <<TEXT
a line

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_quote
    text = <<TEXT
""quoted text: line 1
""quoted text: line 2
TEXT

    md_text = <<TEXT
> quoted text: line 1
> quoted text: line 2

TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_table
    text = <<TEXT
||!header 1||!header 2
||cell 1-1||cell 1-2
||cell 2-1||cell 2-2
||cell 3-1 (a bit wider)||cell 3-2
TEXT

    md_text = <<TEXT
|header 1              |header 2|
|----------------------|--------|
|cell 1-1              |cell 1-2|
|cell 2-1              |cell 2-2|
|cell 3-1 (a bit wider)|cell 3-2|

TEXT

    html =<<HTML
<table>
<tr><th>header 1</th><th>header 2</th></tr>
<tr><td>cell 1-1</td><td>cell 1-2</td></tr>
<tr><td>cell 2-1</td><td>cell 2-2</td></tr>
<tr><td>cell 3-1 (a bit wider)</td><td>cell 3-2</td></tr>
</table>

HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @gfm_formatter.format(tree).to_s)
    assert_equal(html, @formatter.format(tree).to_s)
  end

  def test_non_gfm_conformant_table
    text = <<TEXT
||header 1||!header 2
||cell 1-1||cell 1-2
||cell 2-1||cell 2-2
||cell 3-1 (a bit wider)||cell 3-2

TEXT

    md_text = <<TEXT
|header 1              |header 2|
|----------------------|--------|
|cell 1-1              |cell 1-2|
|cell 2-1              |cell 2-2|
|cell 3-1 (a bit wider)|cell 3-2|

TEXT

    html =<<HTML
<table>
<tr><td>header 1</td><th>header 2</th></tr>
<tr><td>cell 1-1</td><td>cell 1-2</td></tr>
<tr><td>cell 2-1</td><td>cell 2-2</td></tr>
<tr><td>cell 3-1 (a bit wider)</td><td>cell 3-2</td></tr>
</table>

HTML

#    assert_raise(MarkDownFormat::TableNodeFormatter::NotConformantStyleError) do
      tree = BlockParser.parse(text.lines.to_a)
      assert_equal(html, @gfm_formatter.format(tree).to_s)
      assert_equal(html, @formatter.format(tree).to_s)
      assert_equal(md_text, @forced_gfm_formatter.format(tree).to_s)
#    end
  end

  def test_non_gfm_conformant_table_with_multi_headers
    text = <<TEXT
||!header 1-1||!header 1-2
||!header 2-1||!header 2-2
||cell 1-1||cell 1-2
||cell 2-1||cell 2-2
||cell 3-1 (a bit wider)||cell 3-2
TEXT

    md_text = <<TEXT
|header 1-1            |header 1-2|
|----------------------|----------|
|header 2-1            |header 2-2|
|cell 1-1              |cell 1-2  |
|cell 2-1              |cell 2-2  |
|cell 3-1 (a bit wider)|cell 3-2  |

TEXT

    html = <<HTML
<table>
<tr><th>header 1-1</th><th>header 1-2</th></tr>
<tr><th>header 2-1</th><th>header 2-2</th></tr>
<tr><td>cell 1-1</td><td>cell 1-2</td></tr>
<tr><td>cell 2-1</td><td>cell 2-2</td></tr>
<tr><td>cell 3-1 (a bit wider)</td><td>cell 3-2</td></tr>
</table>

HTML

#    assert_raise(MarkDownFormat::TableNodeFormatter::NotConformantStyleError) do
      tree = BlockParser.parse(text.lines.to_a)
      assert_equal(html, @gfm_formatter.format(tree).to_s)
      assert_equal(html, @formatter.format(tree).to_s)
      assert_equal(md_text, @forced_gfm_formatter.format(tree).to_s)
#    end
  end

  def test_non_gfm_conformant_table_with_multicolumn_cells
    text = <<TEXT
||!header 1-1||!header 1-2||!header 1-3||!header 1-4
||cell 1-1||cell 1-2||cell 1-3||cell 1-4
||cell 2-1||>cell 2-2||cell 2-4
||cell 3-1 (a bit wider)||cell 3-2||cell 3-3||cell 3-4
TEXT

    md_text = <<TEXT
|header 1-1            |header 1-2|header 1-3|header 1-4|
|----------------------|----------|----------|----------|
|cell 1-1              |cell 1-2  |cell 1-3  |cell 1-4  |
|cell 2-1              |cell 2-2  |          |cell 2-4  |
|cell 3-1 (a bit wider)|cell 3-2  |cell 3-3  |cell 3-4  |

TEXT

    html = <<HTML
<table>
<tr><th>header 1-1</th><th>header 1-2</th><th>header 1-3</th><th>header 1-4</th></tr>
<tr><td>cell 1-1</td><td>cell 1-2</td><td>cell 1-3</td><td>cell 1-4</td></tr>
<tr><td>cell 2-1</td><td colspan="2">cell 2-2</td><td>cell 2-4</td></tr>
<tr><td>cell 3-1 (a bit wider)</td><td>cell 3-2</td><td>cell 3-3</td><td>cell 3-4</td></tr>
</table>

HTML

#    assert_raise(MarkDownFormat::TableNodeFormatter::NotConformantStyleError) do
      tree = BlockParser.parse(text.lines.to_a)
      assert_equal(html, @gfm_formatter.format(tree).to_s)
      assert_equal(html, @formatter.format(tree).to_s)
      assert_equal(md_text, @forced_gfm_formatter.format(tree).to_s)
#    end
  end

  def test_non_gfm_conformant_table_with_multirow_cells
    text = <<TEXT
||!header 1-1||!header 1-2||!header 1-3||!header 1-4
||cell 1-1||cell 1-2||^cell 1-3||cell 1-4
||cell 2-1||>cell 2-2||cell 2-4
||cell 3-1 (a bit wider)||cell 3-2||cell 3-3||cell 3-4
TEXT

    md_text = <<TEXT
|header 1-1            |header 1-2|header 1-3|header 1-4|
|----------------------|----------|----------|----------|
|cell 1-1              |cell 1-2  |cell 1-3  |cell 1-4  |
|cell 2-1              |cell 2-2  |          |cell 2-4  |
|cell 3-1 (a bit wider)|cell 3-2  |cell 3-3  |cell 3-4  |

TEXT

    html = <<HTML
<table>
<tr><th>header 1-1</th><th>header 1-2</th><th>header 1-3</th><th>header 1-4</th></tr>
<tr><td>cell 1-1</td><td>cell 1-2</td><td rowspan=\"2\">cell 1-3</td><td>cell 1-4</td></tr>
<tr><td>cell 2-1</td><td colspan="2">cell 2-2</td><td>cell 2-4</td></tr>
<tr><td>cell 3-1 (a bit wider)</td><td>cell 3-2</td><td>cell 3-3</td><td>cell 3-4</td></tr>
</table>

HTML

#    assert_raise(MarkDownFormat::TableNodeFormatter::NotConformantStyleError) do
      tree = BlockParser.parse(text.lines.to_a)
      assert_equal(html, @gfm_formatter.format(tree).to_s)
      assert_equal(html, @formatter.format(tree).to_s)
      assert_equal(md_text, @forced_gfm_formatter.format(tree).to_s)
#    end
  end

  def test_list
    text = <<TEXT
* item 1
* item 2
** item 2-1
** item 2-2
*** item 2-2-1
TEXT

    md_text = <<TEXT
* item 1
* item 2
  * item 2-1
  * item 2-2
    * item 2-2-1

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_enum_list
    text = <<TEXT
# item 1
# item 2
## item 2-1
## item 2-2
### item 2-2-1
TEXT

    md_text = <<TEXT
1. item 1
1. item 2
  2. item 2-1
  2. item 2-2
    3. item 2-2-1

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_heading
    text = <<TEXT
!!heading
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("## heading#{$/ * 2}", @formatter.format(tree).to_s)
  end

  def test_paragraph
    text = <<TEXT
the first paragraph

the second paragraph
TEXT

    md_text = <<TEXT
the first paragraph

the second paragraph

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_escape
    text = "test string with *asterisk, _underscore and a html tag <h1>"
    md_text = "test string with \\*asterisk, \\_underscore and a html tag &lt;h1&gt;#{$/}"
    gfm_text = "test string with \\*asterisk, \\_underscore and a html tag \\<h1\\>#{$/}"

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
    assert_equal(gfm_text, @gfm_formatter.format(tree).to_s)
  end

  def test_not_escaped
    text = <<TEXT
<<<
a verbatim asterisk *
a verbatim _underscore_
>>>
TEXT

    gfm_text = <<TEXT
```
a verbatim asterisk *
a verbatim _underscore_
```

TEXT

    md_text = <<TEXT
    a verbatim asterisk *
    a verbatim _underscore_

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(gfm_text, @gfm_formatter.format(tree).to_s)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_document
    text = <<TEXT
!! heading

# item 1
## item 1-1

a paragraph for testing a striked through ==string with an ''emphasis'' in it.==
TEXT

    md_text = <<TEXT
## heading

1. item 1
  2. item 1-1

a paragraph for testing a striked through ~~string with an _emphasis_ in it.~~

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_decorator_for_verbatim
    text = <<TEXT
//@code[ruby]
 def bonjour!
   puts "Bonjour!"
 end
TEXT

    gfm_text =<<TEXT
```ruby
def bonjour!
  puts "Bonjour!"
end
```

TEXT

    md_text = <<TEXT
    def bonjour!
      puts "Bonjour!"
    end

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(gfm_text, @gfm_formatter.format(tree).to_s)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_decorator_for_verbatim_block
    text = <<TEXT
//@code[ruby]
<<<
def bonjour!
  puts "Bonjour!"
end
>>>
TEXT

    gfm_text =<<TEXT
```ruby
def bonjour!
  puts "Bonjour!"
end
```

TEXT

    md_text = <<TEXT
    def bonjour!
      puts "Bonjour!"
    end

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(gfm_text, @gfm_formatter.format(tree).to_s)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end
end

