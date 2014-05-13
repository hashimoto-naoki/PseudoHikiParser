#!/usr/bin/env ruby

require 'stringio'
require 'shellwords'
require 'minitest/autorun'
require './bin/pseudohiki2html.rb'

class TC_OptionManager < MiniTest::Unit::TestCase
  include PseudoHiki

  def set_argv(command_line_str)
    ARGV.replace Shellwords.split(command_line_str)
  end

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
