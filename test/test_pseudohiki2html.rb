#!/usr/bin/env ruby

require 'stringio'
require 'shellwords'
require 'minitest/autorun'
require 'pseudohiki/converter'

def set_argv(command_line_str)
  ARGV.replace Shellwords.split(command_line_str)
end

class TC_OptionManager < MiniTest::Unit::TestCase
  include PseudoHiki

  def test_set_options_from_command_line
    set_argv("-fx -s -m 'Table of Contents' -c css/with_toc.css wikipage.txt -o wikipage_with_toc.html")

    options = OptionManager.new
    options.set_options_from_command_line

    assert_equal("xhtml1", options[:html_version].version)
    assert_equal(true, options[:split_main_heading])
    assert_equal("Table of Contents", options[:toc])
    assert_equal(nil, options[:title])
    assert_equal("css/with_toc.css", options[:css])
    assert_equal("wikipage_with_toc.html", File.basename(options[:output]))
  end

  def test_set_options_from_command_line2
    set_argv("-f h -m 'Table of Contents' -w 'Title' -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line

    assert_equal("html4", options[:html_version].version)
    assert_equal(false, options[:split_main_heading])
    assert_equal("Table of Contents", options[:toc])
    assert_equal("Title", options[:title])
    assert_equal("css/with_toc.css", options[:css])
    assert_equal(nil, options[:output])
  end

  def test_set_options_from_input_file
    input_data = <<LINES
//title: Title set in the input file
//toc: Table of Contents set in the input file

paragraph
LINES
    set_argv("-f h -m 'Table of Contents' -w 'Title' -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line
    options.set_options_from_input_file(input_data.each_line.to_a)

    assert_equal("Table of Contents set in the input file", options[:toc])
    assert_equal("Title set in the input file", options[:title])
  end

  def test_set_options_from_input_file_overwritten_by_command_line_options
    input_data = <<LINES
//title: Title set in the input file
//toc: Table of Contents set in the input file

paragraph
LINES
    set_argv("-F -f h -m 'Table of Contents' -w 'Title' -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line
    options.set_options_from_input_file(input_data.each_line.to_a)

    assert_equal("Table of Contents", options[:toc])
    assert_equal("Title", options[:title])
  end

  def test_set_options_from_input_file_overwritten_by_command_line_options2
    input_data = <<LINES
//title: Title set in the input file
//toc: Table of Contents set in the input file

paragraph
LINES
    set_argv("-F -f h -m 'Table of Contents' -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line
    options.set_options_from_input_file(input_data.each_line.to_a)

    assert_equal("Table of Contents", options[:toc])
    assert_equal("Title set in the input file", options[:title])
  end

  def test_option_not_in_command_line_nor_in_input_file
    input_data = <<LINES
//toc: Table of Contents set in the input file

paragraph
LINES
    set_argv("-F -f h -m 'Table of Contents' -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line
    options.set_options_from_input_file(input_data.each_line.to_a)

    assert_equal("Table of Contents", options[:toc])
    assert_equal(nil, options[:title])
  end
end

class TC_PageComposer < MiniTest::Unit::TestCase
  include PseudoHiki

  def setup
    @input_lines = <<HIKI.each_line.to_a
!Title

!![heading1]Heading1

paragraph

paragran

!![heading2]Heading2

!!![heading2-1]Heading2-1

paragraph

paragraph

HIKI

  end

  def test_create_plain_table_of_contents
    toc_in_plain_text = <<TEXT
  * Heading1
  * Heading2
    * Heading2-1
TEXT
    set_argv("-fg -s -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line

    toc = PageComposer.new(options).create_plain_table_of_contents(@input_lines)

    assert_equal(toc_in_plain_text, toc)
  end

  def test_create_html_table_of_contents
    toc_in_html = <<TEXT
<ul>
<li><a href="#HEADING1" title="toc_item: Heading1">Heading1
</a></li>
<li><a href="#HEADING2" title="toc_item: Heading2">Heading2
</a><ul>
<li><a href="#HEADING2-1" title="toc_item: Heading2-1">Heading2-1
</a></li>
</ul>
</li>
</ul>
TEXT

    set_argv("-fh5 -s -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line

    toc = PageComposer.new(options).create_html_table_of_contents(@input_lines).join

    assert_equal(toc_in_html, toc)
  end

  def test_create_table_of_contents
    set_argv("-c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line
    toc = PageComposer.new(options).create_table_of_contents(@input_lines)
    assert_equal("", toc)

    toc_in_plain_text = <<TEXT
  * Heading1
  * Heading2
    * Heading2-1
TEXT

    set_argv("-fg -m 'table of contents' -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line
    toc = PageComposer.new(options).create_table_of_contents(@input_lines)
    assert_equal(toc_in_plain_text, toc)

    toc_in_html = <<TEXT
<ul>
<li><a href="#HEADING1" title="toc_item: Heading1">Heading1
</a></li>
<li><a href="#HEADING2" title="toc_item: Heading2">Heading2
</a><ul>
<li><a href="#HEADING2-1" title="toc_item: Heading2-1">Heading2-1
</a></li>
</ul>
</li>
</ul>
TEXT

    set_argv("-fh5 -m 'table of contents' -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line
    toc = PageComposer.new(options).create_table_of_contents(@input_lines).join
    assert_equal(toc_in_html, toc)
  end

  def test_output_in_gfm_with_toc
    input = <<TEXT.each_line.to_a
//title: Test Data
//toc: Table of Contents

!Test Data

!![first]The first heading

Paragraph

!![second]The second heading

Paragraph
TEXT

output = <<GFM
# Test Data


## Table of Contents

  * The first heading
  * The second heading

## The first heading

Paragraph

## The second heading

Paragraph

GFM

    set_argv("-fg -s -c css/with_toc.css wikipage.txt")

    options = OptionManager.new
    options.set_options_from_command_line
    options.set_options_from_input_file(input)

    html = PageComposer.new(options).compose_html(input).join

    assert_equal(output, html)
  end
end
