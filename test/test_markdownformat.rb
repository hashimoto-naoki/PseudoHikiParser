#!/usr/bin/env ruby

require 'test/unit'
require 'pseudohiki/markdownformat'

class TC_MarkDownFormat < Test::Unit::TestCase
  include PseudoHiki

  def setup
    @formatter = MarkDownFormat.create
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

  def test_hr
    text = "----#{$/}"
    md_text = "----#{$/}"
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_verbatim
    text = <<TEXT
 verbatim ''line'' 1
 verbatim line 2
TEXT

    md_text =<<TEXT
```
verbatim ''line'' 1
verbatim line 2
```

TEXT

    tree = BlockParser.parse(text.lines.to_a)
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
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_non_gfm_conformant_table
    text = <<TEXT
||!header 1||header 2
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

#    assert_raise(MarkDownFormat::TableNodeFormatter::NotConformantStyleError) do
      tree = BlockParser.parse(text.lines.to_a)
      assert_equal(md_text, @formatter.format(tree).to_s)
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

#    assert_raise(MarkDownFormat::TableNodeFormatter::NotConformantStyleError) do
      tree = BlockParser.parse(text.lines.to_a)
      assert_equal(md_text, @formatter.format(tree).to_s)
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

#    assert_raise(MarkDownFormat::TableNodeFormatter::NotConformantStyleError) do
      tree = BlockParser.parse(text.lines.to_a)
      assert_equal(md_text, @formatter.format(tree).to_s)
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
    text = "test string with *asterisk and _underscore"
    md_text = "test string with \\*asterisk and \\_underscore#{$/}"

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(md_text, @formatter.format(tree).to_s)
  end

  def test_not_escaped
    text = <<TEXT
<<<
a verbatim asterisk *
a verbatim _underscore_
>>>
TEXT

    md_text = <<TEXT
```
a verbatim asterisk *
a verbatim _underscore_
```

TEXT

    tree = BlockParser.parse(text.lines.to_a)
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
end

