#!/usr/bin/env ruby

require 'test/unit'
require 'pseudohiki/plaintextformat'

class TC_PlainTextFormat < Test::Unit::TestCase
  include PseudoHiki

  def setup
    @formatter = PlainTextFormat.create
    @verbose_formatter = PlainTextFormat.create(true)
  end
  
  def test_plain
    text = <<TEXT
test string
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("test string\n", @formatter.format(tree).to_s)
  end

  def test_em
    text = <<TEXT
A test string with ''emphasis'' is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with emphasis is here.\n", @formatter.format(tree).to_s)
  end

  def test_strong
    text = <<TEXT
A test string with '''strong''' is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with strong is here.\n", @formatter.format(tree).to_s)
  end

  def test_link_url
    text = <<TEXT
A test string with a [[link|http://www.example.org/]] is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with a link is here.\n", @formatter.format(tree).to_s)
    assert_equal("A test string with a link (http://www.example.org/) is here.\n",
                 @verbose_formatter.format(tree).to_s)
  end

  def test_link_image
    text = <<TEXT
A test string with an [[image|image.jpg]] is here.
TEXT
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal("A test string with an image is here.\n", @formatter.format(tree).to_s)
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
end
