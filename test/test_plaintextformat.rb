#!/usr/bin/env ruby

require 'minitest/autorun'
require 'pseudohiki/plaintextformat'

class TC_PlainTextFormat < MiniTest::Unit::TestCase
  include PseudoHiki

  def setup
    @formatter = PlainTextFormat.create
    @verbose_formatter = PlainTextFormat.create(:verbose_mode => true)
    @strict_formatter = PlainTextFormat.create(:strict_mode => true)
  end
  
  def test_plain
    text = <<TEXT
test string
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("test string\n\n", @formatter.format(tree).to_s)
  end

  def test_em
    text = <<TEXT
A test string with ''emphasis'' is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with emphasis is here.\n\n", @formatter.format(tree).to_s)
  end

  def test_strong
    text = <<TEXT
A test string with '''strong''' is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with strong is here.\n\n", @formatter.format(tree).to_s)
  end

  def test_del
    text = <<TEXT
A test string ==with deleted words ==is here.
TEXT
    expected_text = <<TEXT
A test string is here.

TEXT

    expected_text_in_verbose_mode = <<TEXT
A test string [deleted:with deleted words ]is here.

TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, @formatter.format(tree).to_s)
    assert_equal(expected_text_in_verbose_mode, @verbose_formatter.format(tree).to_s)
  end

  def test_literal
    text = <<TEXT
A test string with a ``literal`` is here.
TEXT
    expected_text = <<TEXT
A test string with a literal is here.

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, @formatter.format(tree).to_s)
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

  def test_link_url
    text = <<TEXT
A test string with a [[link|http://www.example.org/]] is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with a link is here.\n\n", @formatter.format(tree).to_s)
    assert_equal("A test string with a link (http://www.example.org/) is here.\n\n",
                 @verbose_formatter.format(tree).to_s)
  end

  def test_link_url2
    text = <<TEXT
!![develepment_status] Development status of features from the original [[Hiki notation|http://hikiwiki.org/en/TextFormattingRules.html]]
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(" Development status of features from the original Hiki notation\n", @formatter.format(tree).to_s)
    assert_equal(" Development status of features from the original Hiki notation (http://hikiwiki.org/en/TextFormattingRules.html)\n",
                 @verbose_formatter.format(tree).to_s)
  end

  def test_link_image
    text = <<TEXT
A test string with an [[image|image.jpg]] is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with an image is here.\n\n", @formatter.format(tree).to_s)
  end

  def test_commentout
    text = <<TEXT
lines including a comment out in these
//Comment out
another line
TEXT
    expected_text = <<TEXT
lines including a comment out in these

another line

TEXT

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, @formatter.format(tree).to_s)
  end

  def test_heading
    text = <<TEXT
!!heading
a normal line
TEXT

    expected_text = <<TEXT
heading
a normal line

TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, @formatter.format(tree).to_s)
  end

  def test_desc
    text = <<TEXT
:tel: 03-xxxx-xxxx
:: 03-yyyy-yyyy
:fax: 03-xxxx-xxxx
TEXT

    expected_text = <<TEXT
tel:	03-xxxx-xxxx
	03-yyyy-yyyy
fax:	03-xxxx-xxxx
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, @formatter.format(tree).to_s)
  end

  def test_table
    text = <<TEXT
||cell 1-1||^>> cell 1-2||cell 1-5
||cell 2-1||cell 2-5
TEXT

    expected_text = <<TEXT
cell 1-1	cell 1-2			cell 1-5
cell 2-1				cell 2-5
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, @formatter.format(tree).to_s)
  end

  def test_verbose_mode_table
    text = <<TEXT
||cell 1-1||^>> cell 1-2||cell 1-5
||cell 2-1||cell 2-5
TEXT

    expected_verbose_text = <<TEXT
cell 1-1	cell 1-2	==	==	cell 1-5
cell 2-1	||	||	||	cell 2-5
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_verbose_text, @verbose_formatter.format(tree).to_s)
  end

  def test_verbose_mode_table_with_expansion_in_the_last_column
    text = <<TEXT
||cell 1-1||^> cell 1-2||>cell 1-4
||cell 2-1||cell 2-4||cell 2-5
TEXT

    expected_verbose_text = <<TEXT
cell 1-1	cell 1-2	==	cell 1-4	==
cell 2-1	||	||	cell 2-4	cell 2-5
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_verbose_text, @verbose_formatter.format(tree).to_s)
  end

  def test_malformed_table
    well_formed_text = <<TEXT
||cell 1-1||>>cell 1-2,3,4||cell 1-5
||cell 2-1||^>cell 2-2,3 3-2,3||cell 2-4||cell 2-5
||cell 3-1||cell 3-4||cell 3-5
||cell 4-1||cell 4-2||cell 4-3||cell 4-4||cell 4-5
TEXT

    expected_well_formed_text = <<TEXT
cell 1-1	cell 1-2,3,4	==	==	cell 1-5
cell 2-1	cell 2-2,3 3-2,3	==	cell 2-4	cell 2-5
cell 3-1	||	||	cell 3-4	cell 3-5
cell 4-1	cell 4-2	cell 4-3	cell 4-4	cell 4-5
TEXT

    tree = BlockParser.parse(well_formed_text.lines.to_a)
    assert_equal(expected_well_formed_text, @verbose_formatter.format(tree).to_s)

    mal_formed_text = <<TEXT
||cell 1-1||>>cell 1-2,3,4||cell 1-5
||cell 2-1||^>cell 2-2,3 3-2,3||cell 2-5
||cell 3-1||cell 3-4||cell 3-5
||cell 4-1||cell 4-2||cell 4-3||cell 4-4||cell 4-5
TEXT

    expected_mal_formed_text = <<TEXT
cell 1-1	cell 1-2,3,4	==	==	cell 1-5
cell 2-1	cell 2-2,3 3-2,3	==	cell 2-5
cell 3-1	||	||	cell 3-4	cell 3-5
cell 4-1	cell 4-2	cell 4-3	cell 4-4	cell 4-5
TEXT

    assert_raises(PlainTextFormat::TableNodeFormatter::MalFormedTableError) do
      tree = BlockParser.parse(mal_formed_text.lines.to_a)
      @strict_formatter.format(tree).to_s
    end

    tree = BlockParser.parse(mal_formed_text.lines.to_a)
    assert_equal(expected_mal_formed_text, @verbose_formatter.format(tree).to_s)
  end

  def test_self_format
    text = <<TEXT
A test string ==with deleted words ==is here.
TEXT
    expected_text = <<TEXT
A test string is here.

TEXT

    expected_text_in_verbose_mode = <<TEXT
A test string [deleted:with deleted words ]is here.

TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, PlainTextFormat.format(tree, { :verbose_mode => false }).to_s)
    assert_equal(expected_text_in_verbose_mode, PlainTextFormat.format(tree, { :verbose_mode => true }).to_s)
    assert_equal(expected_text, PlainTextFormat.format(tree, { :verbose_mode => false }).to_s)
  end

  def test_without_sectioning_node
        text = <<TEXT
! Main title

!! first title in header

paragraph

!! second title in header

paragraph2

!! first subtitle in main part

paragraph3

paragraph4

TEXT

    expected_text = <<HTML
 Main title
 first title in header
paragraph

 second title in header
paragraph2

 first subtitle in main part
paragraph3

paragraph4

HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, PlainTextFormat.format(tree, { :verbose_mode => false }).to_s)
  end

  def test_sectioning_node
        text = <<TEXT
! Main title

//@begin[header]
!! first title in header

paragraph

!! second title in header

paragraph2

//@end[header]

!! first subtitle in main part

paragraph3

//@begin[#footer]

paragraph4

//@end[#footer]

TEXT

    expected_text = <<HTML
 Main title
 first title in header
paragraph

 second title in header
paragraph2

 first subtitle in main part
paragraph3

paragraph4

HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_text, PlainTextFormat.format(tree, { :verbose_mode => false }).to_s)
  end
end
