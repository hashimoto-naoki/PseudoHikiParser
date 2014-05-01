#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'optparse'
require 'erb'
require 'pseudohiki/blockparser'
require 'pseudohiki/htmlformat'
require 'pseudohiki/plaintextformat'
require 'pseudohiki/markdownformat'
require 'htmlelement/htmltemplate'
require 'htmlelement'

module PseudoHiki
  class PageComposer
    HEADING_WITH_ID_PAT = /^(!{2,3})\[([A-Za-z][0-9A-Za-z_\-.:]*)\]\s*/o

    PlainFormat = PlainTextFormat.create

    def initialize(options)
      @options = options
    end

    def formatter
      @formatter ||= @options.html_template.new
    end

    def to_plain(line)
      PlainFormat.format(BlockParser.parse(line.lines.to_a)).to_s.chomp
    end

    def create_plain_table_of_contents(lines)
      toc_lines = lines.grep(HEADING_WITH_ID_PAT).map do |line|
        m = HEADING_WITH_ID_PAT.match(line)
        heading_depth = m[1].length
        line.sub(/^!+/o, '*'*heading_depth)
      end

      @options.formatter.format(BlockParser.parse(toc_lines))
    end

    def create_html_table_of_contents(lines)
      toc_lines = lines.grep(HEADING_WITH_ID_PAT).map do |line|
        m = HEADING_WITH_ID_PAT.match(line)
        heading_depth, id = m[1].length, m[2].upcase
        "%s[[%s|#%s]]"%['*'*heading_depth, to_plain(line.sub(HEADING_WITH_ID_PAT,'')), id]
      end
      @options.formatter.format(BlockParser.parse(toc_lines)).tap do |toc|
        toc.traverse do |element|
          if element.kind_of? HtmlElement and element.tagname == "a"
            element["title"] = "toc_item: " + element.children.join.chomp
          end
        end
      end
    end

    def create_table_of_contents(lines)
      return "" unless @options[:toc]
      return create_plain_table_of_contents(lines) unless @options.html_template
      create_html_table_of_contents(lines)
    end

    def split_main_heading(input_lines)
      return "" unless @options[:split_main_heading]
      h1_pos = input_lines.find_index {|line| /^![^!]/o =~ line }
      return "" unless h1_pos
      tree = BlockParser.parse([input_lines.delete_at(h1_pos)])
      @options.formatter.format(tree)
    end

    def create_plain_main(toc, body, h1)
      contents = [body]
      contents.unshift toc unless toc.empty?
      contents.unshift @options.formatter.format(BlockParser.parse("!!" + @options[:toc])) if @options[:toc]
      contents.unshift h1 unless h1.empty?
      contents.join($/)
    end

    def create_html_main(toc, body, h1)
      return nil unless @options[:toc]
      toc_container = formatter.create_element("section").tap do |element|
        element["id"] = "toc"
        element.push formatter.create_element("h2", @options[:toc]) unless @options[:toc].empty?
        element.push toc
      end
      contents_container = formatter.create_element("section").tap do |element|
        element["id"] = "contents"
        element.push body
      end
      main = formatter.create_element("section").tap do |element|
        element["id"] = "main"
        element.push h1 unless h1.empty?
        element.push toc_container
        element.push contents_container
      end
    end

    def create_main(toc, body, h1)
      return create_plain_main(toc, body, h1) unless @options.html_template
      create_html_main(toc, body, h1)
    end

    def create_style(path_to_css_file)
      style = formatter.create_element("style").tap do |element|
        element["type"] = "text/css"
        open(File.expand_path(path_to_css_file)) do |css_file|
          element.push css_file.read
        end
      end
    end

    def compose_body(input_lines)
      tree = BlockParser.parse(input_lines)
      @options.formatter.format(tree)
    end

    def compose_html(input_lines)
      h1 = split_main_heading(input_lines)
      css = @options[:css]
      toc = create_table_of_contents(input_lines)
      body = compose_body(input_lines)
      title = @options.title
      main = create_main(toc,body, h1)

      if @options[:template]
        erb = ERB.new(@options.read_template_file)
        html = erb.result(binding)
      else
        html = @options.create_html_template_with_current_options
        html.head.push create_style(@options[:embed_css]) if @options[:embed_css]
        html.push main||body
      end

      html
    end
  end

  class OptionManager
    include HtmlElement::CHARSET

    PlainVerboseFormat = PlainTextFormat.create(:verbose_mode => true)
    MDFormat = MarkDownFormat.create
    GFMFormat = MarkDownFormat.create(:gfm_style => true)

    class Formatter < Struct.new(:version, :formatter, :template, :ext, :opt_pat)
    end

    VERSIONS = [
                ["html4", HtmlFormat, HtmlTemplate, ".html", /^h/io],
                ["xhtml1", XhtmlFormat, XhtmlTemplate, ".html", /^x/io],
                ["html5", Xhtml5Format, Xhtml5Template, ".html", /^h5/io],
                ["plain", PageComposer::PlainFormat, nil, ".plain", /^p/io],
                ["plain_verbose", PlainVerboseFormat, nil, ".plain", /^pv/io],
                ["markdown", MDFormat, nil, ".md", /^m/io],
                ["gfm", GFMFormat, nil, ".md", /^g/io]
               ].map {|args| Formatter.new(*args) }

    ENCODING_REGEXP = {
      /^u/io => 'utf8',
      /^e/io => 'euc-jp',
      /^s/io => 'sjis',
      /^l[a-zA-Z]*1/io => 'latin1'
    }

    BOM = "\xef\xbb\xbf"
    BOM.force_encoding("ASCII-8BIT") if BOM.respond_to? :encoding
    FILE_HEADER_PAT = /^\/\//

    ENCODING_TO_CHARSET = {
      'utf8' => UTF8,
      'euc-jp' => EUC_JP,
      'sjis' => SJIS,
      'latin1' => LATIN1
    }

    attr_accessor :need_output_file, :default_title
    attr_reader :input_file_basename

    def self.remove_bom(input=ARGF)
      bom = input.read(3)
      input.rewind unless BOM == bom
    end

    def initialize(options=nil)
      @options = options||{
        :html_version => VERSIONS[0],
        :lang => 'en',
        :encoding => 'utf8',
        :title => nil,
        :css => "default.css",
        :embed_css => nil,
        :base => nil,
        :template => nil,
        :output => nil,
        :force => false,
        :toc => nil,
        :split_main_heading => false
      }
      @written_option_pat = {}
      @options.keys.each {|opt| @written_option_pat[opt] = /^\/\/#{opt}:\s*(.*)$/ }
    end

    def [](key)
      @options[key]
    end

    def[]=(key, value)
      @options[key] = value
    end

    def win32?
      true if RUBY_PLATFORM =~ /win/i
    end

    def value_given?(value)
      value and not value.empty?
    end

    def html_template
      self[:html_version].template
    end

    def formatter
      self[:html_version].formatter
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

    def title
      self[:title]||@default_title||"-"
    end

    def read_template_file
      File.read(File.expand_path(self[:template]), :encoding => self.charset)
    end

    def set_html_version(version)
      VERSIONS.each do |v|
        if v.version == version
          return self[:html_version] = v
        else
          self[:html_version] = v if v.opt_pat =~ version
        end
      end
      STDERR.puts "\"#{version}\" is an invalid option for --format-version. \"#{self[:html_version].version}\" is chosen instead."
    end

    def set_html_encoding(given_opt)
      if ENCODING_REGEXP.values.include? given_opt
        self[:encoding] = given_opt
      else
        ENCODING_REGEXP.each do |pat, encoding|
          self[:encoding] = encoding if pat =~ given_opt
        end
        STDERR.puts "\"#{self[:encoding]}\" is chosen as an encoding system, instead of \"#{given_opt}\"."
      end
    end

    def set_encoding(given_opt)
      return nil unless String.new.respond_to? :encoding
      external, internal = given_opt.split(/:/o)
      Encoding.default_external = external if external
      Encoding.default_internal = internal if internal
    end

    def parse_command_line_options
      OptionParser.new("** Convert texts written in a Hiki-like notation into HTML **
USAGE: #{File.basename(__FILE__)} [options]") do |opt|
        opt.on("-f [html_version]", "--format-version [=format_version]",
               "HTML version to be used. Choose html4, xhtml1, html5, plain, plain_verbose, markdown or gfm (default: #{self[:html_version].version})") do |version|
          self.set_html_version(version)
        end

        opt.on("-l [lang]", "--lang [=lang]",
               "Set the value of charset attributes (default: #{self[:lang]})") do |lang|
          self[:lang] = lang if value_given?(lang)
        end

        opt.on("-e [encoding]", "--format-encoding [=encoding]",
               "Available options: utf8, euc-jp, sjis, latin1 (default: #{self[:encoding]})") do |given_opt|
          self.set_html_encoding(given_opt)
        end

        opt.on("-E [ex[:in]]", "--encoding [=ex[:in]]",
               "Specify the default external and internal character encodings (same as the option of MRI") do |given_opt|
          self.set_encoding(given_opt)
        end

        #use '-w' to avoid the conflict with the short option for '[-t]emplate'
        opt.on("-w [(window) title]", "--title [=title]",
               "Set the value of the <title> element (default: the basename of the input file)") do |title|
          self[:title] = title if value_given?(title)
        end

        opt.on("-c [css]", "--css [=css]",
               "Set the path to a css file to be used (default: #{self[:css]})") do |css|
          self[:css] = css
        end

        opt.on("-C [path_to_css_file]", "--embed-css [=path_to_css_file]",
               "Set the path to a css file to embed (default: not to embed)") do |path_to_css_file|
          self[:embed_css] = path_to_css_file
        end

        opt.on("-b [base]", "--base [=base]",
               "Specify the value of href attribute of the <base> element (default: not specified)") do |base_dir|
          self[:base] = base_dir if value_given?(base_dir)
        end

        opt.on("-t [template]", "--template [=template]",
               "Specify a template file written in eruby format with \"<%= body %>\" inside (default: not specified)") do |template|
          self[:template] = template if value_given?(template)
        end

        opt.on("-o [output]", "--output [=output]",
               "Output to the specified file. If no file is given, \"[input_file_basename].html\" will be used.(default: STDOUT)") do |output|
          self[:output] = File.expand_path(output) if value_given?(output)
          self.need_output_file = true
        end

        opt.on("-F", "--force",
               "Force to apply command line options.(default: false)") do |force|
          self[:force] = force
        end

        opt.on("-m [contents-title]", "--table-of-contents [=contents-title]",
               "Include the list of h2 and/or h3 headings with ids.(default: nil)") do |toc_title|
          self[:toc] = toc_title
        end

        opt.on("-s", "--split-main-heading",
               "Split the first h1 element") do |should_be_split|
          self[:split_main_heading] = should_be_split
        end

        opt.parse!
      end
    end

    def check_argv
      case ARGV.length
      when 0
        if self.need_output_file and not self[:output]
          raise "You must specify a file name for output"
        end
      when 1
        self.read_input_filename(ARGV[0])
      end
    end

    def set_options_from_command_line
      parse_command_line_options
      check_argv
      @default_title = @input_file_basename
    end

    def set_options_from_input_file(input_lines)
      input_lines.each do |line|
        break if FILE_HEADER_PAT !~ line
        line = line.chomp
        @options.keys.each do |opt|
          if @written_option_pat[opt] =~ line and not self[:force]
            self[opt] = $1
          end
        end
      end
    end

    def create_html_template_with_current_options
      return [] unless self.html_template
      html = self.html_template.new
      html.charset = self.charset
      html.language = self[:lang]
      html.default_css = self[:css] if self[:css]
      html.base = self.base if self[:base]
      html.title = self.title
      html
    end

    def read_input_filename(filename)
      @input_file_dir, @input_file_name = File.split(File.expand_path(filename))
      @input_file_basename = File.basename(@input_file_name,".*")
    end

    def output_filename
      return nil unless self.need_output_file
      if self[:output]
        File.expand_path(self[:output])
      else
        File.join(@input_file_dir, @input_file_basename + self[:html_version].ext)
      end
    end

    def open_output
      if self.output_filename
        open(self.output_filename, "w") {|f| yield f }
      else
        yield STDOUT
      end
    end
  end
end

if $0 == __FILE__
  options = PseudoHiki::OptionManager.new
  options.set_options_from_command_line

  if $KCODE
    PseudoHiki::OptionManager::ENCODING_REGEXP.each do |pat, encoding|
      options[:encoding] = encoding if pat =~ $KCODE and not options[:force]
    end
  end

  PseudoHiki::OptionManager.remove_bom
  input_lines = ARGF.readlines.map {|line| line.encode(options.charset) }
  options.set_options_from_input_file(input_lines)
  html = PseudoHiki::PageComposer.new(options).compose_html(input_lines)

  options.open_output {|out| out.puts html }
end
