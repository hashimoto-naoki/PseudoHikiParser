#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'optparse'
require 'erb'
require 'pseudohiki/version'
require 'pseudohiki/blockparser'
require 'pseudohiki/autolink'
require 'pseudohiki/htmlformat'
require 'pseudohiki/plaintextformat'
require 'pseudohiki/markdownformat'
require 'pseudohiki/utils'
require 'htmlelement/htmltemplate'
require 'htmlelement'

module PseudoHiki
  class PageComposer
    HEADING_WITH_ID_PAT = /^(!{2,3})\[([A-Za-z][0-9A-Za-z_\-.:]*)\]\s*/o

    PlainFormat = PlainTextFormat.create

    class BaseComposer
      def initialize(options)
        @options = options
        @is_toc_item_pat = proc_for_is_toc_item_pat
      end

      def compose_body(tree)
        @options.formatter.format(tree)
      end

      private

      def proc_for_is_toc_item_pat
        proc do |node|
          node.kind_of?(PseudoHiki::BlockParser::HeadingLeaf) and
            (2..3).include? node.level and
            node.node_id
        end
      end

      def collect_nodes_for_table_of_contents(tree)
        Utils::NodeCollector.select(tree) {|node| @is_toc_item_pat.call(node) }
      end

      def to_plain(line)
        PlainFormat.format(line).to_s
      end

      def create_style(path_to_css_file); "".freeze; end
    end

    class HtmlComposer < BaseComposer
      def create_table_of_contents(tree)
        @options.formatter.format(create_toc_tree(tree)).tap do |toc|
          toc.traverse do |element|
            if element.kind_of? HtmlElement and element.tagname == "a"
              element["title"] = "toc_item: " + element.children.join.chomp
            end
          end
        end
      end

      def create_main(toc, body, h1)
        return nil unless @options[:toc]
        main = formatter.create_element("section").tap do |element|
          element["id"] = "main"
          element.push h1 unless h1.empty?
          element.push create_toc_container(toc)
          element.push create_contents_container(body)
        end
      end

      def create_style(path_to_css_file)
        style = formatter.create_element("style").tap do |element|
          element["type"] = "text/css"
          open(File.expand_path(path_to_css_file)) do |css_file|
            element.push css_file.read
          end
        end
      end

      private

      def formatter
        @formatter ||= @options.html_template.new
      end

      def create_toc_tree(tree, newline=nil)
        toc_lines = collect_nodes_for_table_of_contents(tree).map do |line|
          format("%s[[%s|#%s]]#{newline}",
                 '*' * line.level,
                 to_plain(line).lstrip,
                 line.node_id.upcase)
        end
        BlockParser.parse(toc_lines)
      end

      def create_toc_container(toc)
        formatter.create_element("section").tap do |elm|
          elm["id"] = "toc"
          title = @options[:toc]
          elm.push formatter.create_element("h2", title) unless title.empty?
          elm.push toc
        end
      end

      def create_contents_container(body)
        formatter.create_element("section").tap do |elm|
          elm["id"] = "contents"
          elm.push body
        end
      end
    end

    class PlainComposer < BaseComposer
      def create_table_of_contents(tree)
        toc_lines = collect_nodes_for_table_of_contents(tree).map do |toc_node|
          ('*' * toc_node.level) + to_plain(toc_node)
        end

        @options.formatter.format(BlockParser.parse(toc_lines))
      end

      def create_main(toc, body, h1)
        contents = [body]
        contents.unshift toc unless toc.empty?
        if title = @options[:toc]
          toc_title = @options.formatter.format(BlockParser.parse("!!" + title))
          contents.unshift toc_title
        end
        contents.unshift h1 unless h1.empty?
        contents.join($/)
      end
    end

    class GfmComposer < PlainComposer
      def create_table_of_contents(tree)
        toc_lines = collect_nodes_for_table_of_contents(tree).map do |toc_node|
          format("%s[[%s|#%s]]#{$/}",
                 '*' * toc_node.level,
                 to_plain(toc_node).strip,
                 gfm_id(toc_node))
        end

        @options.formatter.format(BlockParser.parse(toc_lines))
      end

      private

      def gfm_id(heading_node)
        MarkDownFormat.convert_into_gfm_id_format(to_plain(heading_node).strip)
      end
    end

    def initialize(options)
      @options = options
      @composer = select_composer.new(options)
    end

    def select_composer
      return GfmComposer if @options[:html_version].version == "gfm"
      @options.html_template ? HtmlComposer : PlainComposer
    end

    def create_table_of_contents(tree)
      return "" unless @options[:toc]
      @composer.create_table_of_contents(tree)
    end

    def split_main_heading(input_lines)
      return "" unless @options[:split_main_heading]
      h1_pos = input_lines.find_index {|line| /^![^!]/o =~ line }
      return "" unless h1_pos
      tree = BlockParser.parse([input_lines.delete_at(h1_pos)])
      @options.formatter.format(tree)
    end

    def compose_html(input_lines)
      h1 = split_main_heading(input_lines)
      css = @options[:css]
      tree = BlockParser.parse(input_lines)
      toc = create_table_of_contents(tree)
      body = @composer.compose_body(tree)
      title = @options.title
      main = @composer.create_main(toc, body, h1)
      choose_template(main, body, binding)
    end

    def choose_template(main, body, current_binding)
      if @options[:template]
        html = ERB.new(@options.read_template_file).result(current_binding)
      else
        html = @options.create_html_template_with_current_options
        embed_css = @options[:embed_css]
        html.head.push @composer.create_style(embed_css) if embed_css
        html.push main || body
      end

      html
    end
  end

  class OptionManager
    include HtmlElement::CHARSET

    PlainVerboseFormat = PlainTextFormat.create(:verbose_mode => true)
    MDFormat = MarkDownFormat.create
    GFMFormat = MarkDownFormat.create(:gfm_style => true)

    Formatter = Struct.new(:version, :formatter, :template, :ext, :opt_pat)

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

    @default_options = {
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

    attr_accessor :need_output_file, :default_title
    attr_reader :input_file_basename

    def self.remove_bom(input=ARGF)
      return if input == ARGF and input.filename == "-"
      bom = input.read(3)
      input.rewind unless BOM == bom
    end

    def self.default_options
      @default_options.dup
    end

    def initialize(options=nil)
      @options = options || self.class.default_options
      @written_option_pat = {}
      @options.keys.each do |opt|
        @written_option_pat[opt] = /^\/\/#{opt}:\s*(.*)$/
      end
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
        base_dir = File.join(base_dir, ".")
        base_dir = "file:///" + base_dir if base_dir !~ /^\./o and win32?
      end
      base_dir
    end

    def title
      self[:title] || @default_title || "-"
    end

    def read_template_file
      File.read(File.expand_path(self[:template]), :encoding => charset)
    end

    def set_html_version(version)
      VERSIONS.each do |v|
        if v.version == version
          return self[:html_version] = v
        else
          self[:html_version] = v if v.opt_pat =~ version
        end
      end
      STDERR.puts "\"#{version}\" is an invalid option for --format-version. \
\"#{self[:html_version].version}\" is chosen instead."
    end

    def set_html_encoding(given_opt)
      if ENCODING_REGEXP.values.include? given_opt
        self[:encoding] = given_opt
      else
        ENCODING_REGEXP.each do |pat, encoding|
          self[:encoding] = encoding if pat =~ given_opt
        end
        STDERR.puts "\"#{self[:encoding]}\" is chosen as an encoding system, \
instead of \"#{given_opt}\"."
      end
    end

    def set_encoding(given_opt)
      return nil unless String.new.respond_to? :encoding
      external, internal = given_opt.split(/:/o, 2)
      Encoding.default_external = external if external and not external.empty?
      Encoding.default_internal = internal if internal and not internal.empty?
    end

    def setup_command_line_options
      OptionParser.new("USAGE: #{File.basename($0)} [OPTION]... [FILE]...
Convert texts written in a Hiki-like notation into another format.") do |opt|
        opt.version = PseudoHiki::VERSION

        opt.on("-f [format_version]", "--format-version [=format_version]",
               "Choose a formart for the output. Available options: \
html4, xhtml1, html5, plain, plain_verbose, markdown or gfm \
(default: #{self[:html_version].version})") do |version|
          set_html_version(version)
        end

        opt.on("-l [lang]", "--lang [=lang]",
               "Set the value of charset attributes \
(default: #{self[:lang]})") do |lang|
          self[:lang] = lang if value_given?(lang)
        end

        opt.on("-e [encoding]", "--format-encoding [=encoding]",
               "Available options: utf8, euc-jp, sjis, latin1 \
(default: #{self[:encoding]})") do |given_opt|
          set_html_encoding(given_opt)
        end

        opt.on("-E [ex[:in]]", "--encoding [=ex[:in]]",
               "Specify the default external and internal character encodings \
(same as the option of MRI") do |given_opt|
          set_encoding(given_opt)
        end

        # use '-w' to avoid the conflict with the short option for '[-t]emplate'
        opt.on("-w [(window) title]", "--title [=title]",
               "Set the value of the <title> element \
(default: the basename of the input file)") do |title|
          self[:title] = title if value_given?(title)
        end

        opt.on("-c [css]", "--css [=css]",
               "Set the path to a css file to be used \
(default: #{self[:css]})") do |css|
          self[:css] = css
        end

        opt.on("-C [path_to_css_file]", "--embed-css [=path_to_css_file]",
               "Set the path to a css file to embed \
(default: not to embed)") do |path_to_css_file|
          self[:embed_css] = path_to_css_file
        end

        opt.on("-b [base]", "--base [=base]",
               "Specify the value of href attribute of the <base> element \
(default: not specified)") do |base_dir|
          self[:base] = base_dir if value_given?(base_dir)
        end

        opt.on("-t [template]", "--template [=template]",
               "Specify a template file in eruby format with \"<%= body %>\" \
inside (default: not specified)") do |template|
          self[:template] = template if value_given?(template)
        end

        opt.on("-o [output]", "--output [=output]",
               "Output to the specified file. If no file is given, \
\"[input_file_basename].html\" will be used.(default: STDOUT)") do |output|
          self[:output] = File.expand_path(output) if value_given?(output)
          @need_output_file = true
        end

        opt.on("-F", "--force",
               "Force to apply command line options. \
(default: false)") do |force|
          self[:force] = force
        end

        opt.on("-m [contents-title]", "--table-of-contents [=contents-title]",
               "Include the list of h2 and/or h3 headings with ids. \
(default: nil)") do |toc_title|
          self[:toc] = toc_title
        end

        opt.on("-s", "--split-main-heading",
               "Split the first h1 element") do |should_be_split|
          self[:split_main_heading] = should_be_split
        end

        opt.on("-W", "--with-wikiname",
               "Use WikiNames") do |with_wikiname|
          if with_wikiname
            auto_linker = PseudoHiki::AutoLink::WikiName.new
            PseudoHiki::BlockParser.auto_linker = auto_linker
          end
        end

        opt
      end
    end

    def check_argv
      case ARGV.length
      when 0
        if @need_output_file and not self[:output]
          raise "You must specify a file name for output"
        end
      when 1
        read_input_filename(ARGV[0])
      end
    end

    def parse_command_line_options
      opt = setup_command_line_options
      yield opt if block_given?
      opt.parse!
      check_argv
      @default_title = @input_file_basename
    end

    def set_options_from_input_file(input_lines)
      input_lines.each do |line|
        break if FILE_HEADER_PAT !~ line
        line = line.chomp
        @options.keys.each do |opt|
          next if self[opt] and self[:force]
          self[opt] = $1 if @written_option_pat[opt] =~ line
        end
      end
    end

    def create_html_template_with_current_options
      return [] unless html_template
      html = html_template.new
      html.charset = charset
      html.language = self[:lang]
      html.default_css = self[:css] if self[:css]
      html.base = base if self[:base]
      html.title = title
      html
    end

    def read_input_filename(filename)
      @input_file_dir, @input_file_name = File.split(File.expand_path(filename))
      @input_file_basename = File.basename(@input_file_name, ".*")
    end

    def output_filename
      return nil unless @need_output_file
      if self[:output]
        File.expand_path(self[:output])
      else
        ext = self[:html_version].ext
        File.join(@input_file_dir, @input_file_basename + ext)
      end
    end

    def open_output
      if output_filename
        open(output_filename, "w") {|f| yield f }
      else
        yield STDOUT
      end
    end
  end
end
