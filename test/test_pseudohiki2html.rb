#!/usr/bin/env ruby

require 'stringio'
require 'shellwords'
require 'minitest/autorun'
require 'pseudohiki/converter'
require 'pseudohiki/autolink'

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

    @parsed_tree = BlockParser.parse(@input_lines)
  end

  def test_collect_nodes_for_table_of_contents
    set_argv("-fg -s -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line
    collected_nodes = [[["Heading1\n"]],
                       [["Heading2\n"]],
                       [["Heading2-1\n"]]]

    tree = BlockParser.parse(@input_lines)
    toc_nodes = PageComposer.new(options).collect_nodes_for_table_of_contents(tree)
    assert_equal(collected_nodes, toc_nodes)
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

    toc = PageComposer.new(options).create_plain_table_of_contents(@parsed_tree)

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

    toc = PageComposer.new(options).create_html_table_of_contents(@parsed_tree).join

    assert_equal(toc_in_html, toc)
  end

  def test_create_table_of_contents
    set_argv("-c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line
    toc = PageComposer.new(options).create_table_of_contents(@parsed_tree)
    assert_equal("", toc)

    toc_in_gfm_text = <<TEXT
  * [Heading1](#heading1)
  * [Heading2](#heading2)
    * [Heading2-1](#heading21)
TEXT

    set_argv("-fg -m 'table of contents' -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line
    toc = PageComposer.new(options).create_table_of_contents(@parsed_tree)
    assert_equal(toc_in_gfm_text, toc)

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
    toc = PageComposer.new(options).create_table_of_contents(@parsed_tree).join
    assert_equal(toc_in_html, toc)
  end

  def test_compose_html
    expected_html =<<HTML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html lang="en" xml:lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="UTF-8" />
<title>wikipage</title>
<link href="css/with_toc.css" rel="stylesheet" type="text/css" />
</head>
<body>
<section id="main">
<section id="toc">
<h2>table of contents</h2>
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
<!-- end of toc -->
</section>
<section id="contents">
<section class="h1">
<h1>Title
</h1>
<section class="h2">
<h2 id="HEADING1">Heading1
</h2>
<p>
paragraph
</p>
<p>
paragran
</p>
<!-- end of h2 -->
</section>
<section class="h2">
<h2 id="HEADING2">Heading2
</h2>
<section class="h3">
<h3 id="HEADING2-1">Heading2-1
</h3>
<p>
paragraph
</p>
<p>
paragraph
</p>
<!-- end of h3 -->
</section>
<!-- end of h2 -->
</section>
<!-- end of h1 -->
</section>
<!-- end of contents -->
</section>
<!-- end of main -->
</section>
</body>
</html>
HTML

    expected_gfm_text = <<TEXT
## table of contents

  * [Heading1](#heading1)
  * [Heading2](#heading2)
    * [Heading2-1](#heading21)

# Title

## Heading1

paragraph

paragran

## Heading2

### Heading2-1

paragraph

paragraph

TEXT

    set_argv("-fh5 -m 'table of contents' -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line

    composed_html = PageComposer.new(options).compose_html(@input_lines).to_s
    assert_equal(expected_html, composed_html)

    set_argv("-fg -m 'table of contents' -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line

    composed_gfm_text = PageComposer.new(options).compose_html(@input_lines).join
    assert_equal(expected_gfm_text, composed_gfm_text)
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

  * [The first heading](#the-first-heading)
  * [The second heading](#the-second-heading)

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

  def test_with_wikiname
    current_auto_linker = BlockParser.auto_linker
    set_argv("--with-wikiname wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line

    assert_equal(AutoLink::WikiName, BlockParser.auto_linker.class)

    BlockParser.auto_linker = current_auto_linker
  end

  def test_no_automatical_link_in_verbatim
    verbatim_block_text = <<TEXT.each_line.to_a

a link in a paragraph http://www.example.org/

<<<
http://www.example.org/
>>>
TEXT

    expected_html = <<HTML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html lang="en" xml:lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="UTF-8" />
<title>wikipage</title>
<link href="css/with_toc.css" rel="stylesheet" type="text/css" />
</head>
<body>
<p>
a link in a paragraph <a href="http://www.example.org/">http://www.example.org/</a>
</p>
<pre>
<a href="http://www.example.org/">http://www.example.org/</a>
</pre>
</body>
</html>
HTML

    expected_html_without_auto_link = <<HTML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html lang="en" xml:lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="UTF-8" />
<title>wikipage</title>
<link href="css/with_toc.css" rel="stylesheet" type="text/css" />
</head>
<body>
<p>
a link in a paragraph http://www.example.org/
</p>
<pre>
http://www.example.org/
</pre>
</body>
</html>
HTML

    set_argv("-fh5 -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line

    composed_html = PageComposer.new(options).compose_html(verbatim_block_text).to_s
    assert_equal(expected_html, composed_html)

    set_argv("-fh5 -c css/with_toc.css wikipage.txt")
    options = OptionManager.new
    options.set_options_from_command_line

    current_auto_linker = BlockParser.auto_linker
    BlockParser.auto_linker = AutoLink::Off
    Xhtml5Format.auto_link_in_verbatim = false
    composed_html_without_auto_link = PageComposer.new(options).compose_html(verbatim_block_text).to_s
    assert_equal(expected_html_without_auto_link, composed_html_without_auto_link)
    BlockParser.auto_linker = current_auto_linker
    Xhtml5Format.auto_link_in_verbatim = true
  end
end
