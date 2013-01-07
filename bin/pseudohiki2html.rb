#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'optparse'
require 'erb'
require 'pseudohiki/blockparser'
require 'htmlelement/htmltemplate'
require 'htmlelement'

include PseudoHiki

OPTIONS = {
  :html_version => "html4",
  :lang => 'en',
  :encoding => 'utf8',
  :title => nil,
  :css => "default.css",
  :base => nil,
  :template => nil,
  :output => nil,
  :force => false
}

ENCODING_REGEXP = {
  /^u/io => 'utf8',
  /^e/io => 'euc-jp',
  /^s/io => 'sjis',
  /^l[a-zA-Z]*1/io => 'latin1'
}

HTML_VERSIONS = %w(html4 xhtml1)

def win32? 
  true if RUBY_PLATFORM =~ /win/i
end

class << OPTIONS
  include HtmlElement::CHARSET
  attr_accessor :need_output_file

  ENCODING_TO_CHARSET = {
    'utf8' => UTF8,
    'euc-jp' => EUC_JP,
    'sjis' => SJIS,
    'latin1' => LATIN1
  }

  HTML_TEMPLATES = Hash[*HTML_VERSIONS.zip([HtmlTemplate, XhtmlTemplate]).flatten]
  FORMATTERS = Hash[*HTML_VERSIONS.zip([HtmlFormat, XhtmlFormat]).flatten]

  def html_template
    HTML_TEMPLATES[self[:html_version]]
  end

  def formatter
    FORMATTERS[self[:html_version]]
  end

  def charset
    ENCODING_TO_CHARSET[self[:encoding]]
  end

  def base
    base_dir = self[:base]
    if base_dir and base_dir !~ /[\/\\]\.*$/o
      base_dir = File.join(base_dir,".")
      base_dir = "file:///"+base_dir if base_dir !~ /^\./o and win32?
    end
    base_dir
  end

  def read_template_file
    File.read(File.expand_path(self[:template]))
  end
end

FILE_HEADER_PAT = /^(\xef\xbb\xbf)?\/\//
WRITTEN_OPTION_PAT = {}
OPTIONS.keys.each {|opt| WRITTEN_OPTION_PAT[opt] = /^(\xef\xbb\xbf)?\/\/#{opt}:\s*(.*)$/ }

OptionParser.new("** Convert texts written in a Hiki-like notation into HTML **
USAGE: #{File.basename(__FILE__)} [options]") do |opt|
  opt.on("-h [html_version]", "--html_version [=html_version]",
         "HTML version to be used. Choose html4 or xhtml1 (default: #{OPTIONS[:html_version]})") do |version|
    if HTML_VERSIONS.include? version
      OPTIONS[:html_version] = version
    else
      case version
      when /^x/io
        OPTIONS[:html_version] = HTML_VERSIONS[1] #xhtml1
      end
      STDERR.puts "\"#{version}\" is an invalid option for --html_version. \"#{OPTIONS[:html_version]}\" is chosen instead."
    end
  end

  opt.on("-l [lang]", "--lang [=lang]", 
         "Set the value of charset attributes (default: #{OPTIONS[:lang]})") do |lang|
    OPTIONS[:lang] = lang if (lang and not lang.empty?)
  end

  opt.on("-e [encoding]", "--encoding [=encoding]",
         "Available options: utf8, euc-jp, sjis, latin1 (default: #{OPTIONS[:encoding]})") do |given_opt|
    if ENCODING_REGEXP.values.include? given_opt
      OPTIONS[:encoding] = given_opt
    else
      ENCODING_REGEXP.each do |pat, encoding|
        OPTIONS[:encoding] = encoding if pat =~ given_opt
      end
      STDERR.puts "\"#{OPTIONS[:encoding]}\" is chosen as an encoding system, instead of \"#{given_opt}\"."
    end
  end

  opt.on("-t [title]", "--title [=title]",
           "Set the value of the <title> element (default: the basename of the input file)") do |title|
    OPTIONS[:title] = title if (title and not title.empty?)
  end

  opt.on("-c [css]", "--css [=css]",
           "Set the path to a css file to be used (default: #{OPTIONS[:css]})") {|v| }

  opt.on("-b [base]", "--base [=base]",
       "Specify the value of href attribute of the <base> element (default: not specified)") do |base_dir|
    OPTIONS[:base] = base_dir if (base_dir and not base_dir.empty?)
  end

  opt.on("-t [template]", "--template [=template]",
         "Specify a template file written in eruby format with \"<%= body %>\" inside (default: not specified)") do |template|
    OPTIONS[:template] = template if (template and not template.empty?)
  end

  opt.on("-o [output]", "--output [=output]",
         "Output to the specified file. If no file is given, \"[input_file_basename].html\" will be used.(default: STDOUT)") do |output|
    OPTIONS[:output] = File.expand_path(output) if (output and not output.empty?)
    OPTIONS.need_output_file = true
  end

  opt.on("-f", "--force",
         "Force to apply command line options.(default: false)") do |force|
    OPTIONS[:force] = force
  end

 opt.parse!
end

if $KCODE
  ENCODING_REGEXP.each do |pat, encoding|
    OPTIONS[:encoding] = encoding if pat =~ $KCODE
  end
end

input_file_dir, input_file_name, input_file_basename = nil, nil, nil
output_file_name = nil
input_lines = ARGF.lines.to_a

case ARGV.length
when 0
 if OPTIONS.need_output_file and not OPTIONS[:output]
   raise "You must specify a file name for output"
 end
when 1
  input_file_dir, input_file_name = File.split(File.expand_path(ARGV[0]))
  input_file_basename = File.basename(input_file_name,".*")
end

input_lines.each do |line|
  break if FILE_HEADER_PAT !~ line
  line = line.chomp
  OPTIONS.keys.each do |opt|
    if WRITTEN_OPTION_PAT[opt] =~ line and not OPTIONS[:force]
      OPTIONS[opt] = $2
    end
  end
end

tree = BlockParser.parse(input_lines)
formatter = OPTIONS.formatter.create_plain
body = tree.accept(formatter)
title = OPTIONS[:title]||input_file_basename||"-"

if OPTIONS[:template]
  erb = ERB.new(OPTIONS.read_template_file)
  html = erb.result(binding)
else
  html = OPTIONS.html_template.new
  html.language = OPTIONS[:lang]
  html.charset = OPTIONS.charset
  html.title = title
  html.default_css = OPTIONS[:css] if OPTIONS[:css]
  html.base = OPTIONS.base if OPTIONS[:base]
  html.push body
end

if OPTIONS.need_output_file
  if OPTIONS[:output]
    output_file_name = File.expand_path(OPTIONS[:output])
  else
    output_file_name = File.join(input_file_dir, input_file_basename+".html")
  end
end

if output_file_name
  open(output_file_name, "w") {|f| f.puts html }
else
  STDOUT.puts html
end

#html.default_css = opts[:css_file]||File.join((root_dir||CONFIG_DIR),"default.css")
#html.title.push opts[:title]||input_file_name
#
#html.push HikiBlockParser.new.parse_lines(input_lines).join
#orig_data_link["href"] = "file:///"+input_file_dir
#
#puts output_file_full_name
#
#open(output_file_full_name,"w") do |output_file|
#  output_file.puts html
#end
