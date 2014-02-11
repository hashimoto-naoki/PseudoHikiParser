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
    assert_equal("test string\n", @formatter.format(tree).to_s)
  end

  def test_link_url
    text = <<TEXT
A test string with a [[link|http://www.example.org/]] is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with a [link](http://www.example.org/) is here.\n", @formatter.format(tree).to_s)
  end

  def test_link_image
    image = <<IMAGE
A test for a link to [[an image|image.png]]
IMAGE
    tree = BlockParser.parse(image.lines.to_a)
    assert_equal("A test for a link to ![an image](image.png)\n", @formatter.format(tree).to_s)
  end

  def test_em
    text = "string with ''emphasis'' "
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("string with _emphasis_ ", @formatter.format(tree).to_s)
  end

  def test_strong
    text = "string with '''emphasis''' "
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("string with **emphasis** ", @formatter.format(tree).to_s)
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
    assert_equal("## heading\n", @formatter.format(tree).to_s)
  end
end

