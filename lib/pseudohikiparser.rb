#!/usr/bin/env ruby

require "pseudohiki/htmlformat"
require "pseudohiki/plaintextformat"
require "pseudohiki/markdownformat"
require "pseudohiki/version"

# = PseudoHikiParser -- A converter of texts written in a Hiki-like notation into HTML or other formats.
#
# You may find more detailed information at {PseudoHikiParser Wiki}[https://github.com/nico-hn/PseudoHikiParser/wiki]
#
module PseudoHiki
  # This class provides class methods for converting texts written in a Hiki-like notation into HTML or other formats.
  #
  class Format
    @formatter = {}
    @preset_options = {}
    @type_to_formatter = {}

    [
     [:html, HtmlFormat, nil],
     [:xhtml, XhtmlFormat, nil],
     [:html5, Xhtml5Format, nil],
     [:plain, PlainTextFormat, { :verbose_mode => false }],
     [:plain_verbose, PlainTextFormat, { :verbose_mode => true }],
     [:markdown, MarkDownFormat, { :strict_mode => false, :gfm_style => false }],
     [:gfm, MarkDownFormat, { :strict_mode => false, :gfm_style => true }]
    ].each do |type, formatter, options|
      preset_options = [type, nil]
      @formatter[preset_options] = formatter.create(options)
      @preset_options[type] = preset_options
      @type_to_formatter[type] = formatter
    end

    # Converts <hiki_data> into a format specified by <format_type>
    #
    # <hiki_data> should be a string or an array of strings
    #
    # Options for <format_type> are:
    # [:html] HTML4.1
    # [:xhtml] XHTML1.0
    # [:html5] HTML5
    # [:plain] remove all of tags. certain information such as urls in link tags does not appear in the output
    # [:plain_verbose] similar to :plain, but certain information such as urls in link tags will be kept in the output
    # [:markdown] Markdown
    # [:gfm] GitHub Flavored Markdown
    #
    def self.format(hiki_data, format_type, options=nil, &block)
      tree = BlockParser.parse(hiki_data)

      if options
        @formatter[[format_type, options]] ||= @type_to_formatter[format_type].create(options)
      else
        @formatter[@preset_options[format_type]]
      end.format(tree).tap do |formatted|
        block.call(formatted) if block
      end.to_s
    end

    # Converts <hiki_data> into HTML4.1
    #
    # When you give a block to this method, a tree of HtmlElement objects is passed as the parameter to the block,
    # so you can traverse it, as in the following example:
    #
    #    hiki = <<HIKI
    #    !! heading
    #
    #    paragraph 1 that contains [[a link to a html file|http://www.example.org/example.html]]
    #
    #    paragraph 2 that contains [[a link to a pdf file|http://www.example.org/example.pdf]]
    #    HIKI
    #
    #    html_str = PseudoHiki::Format.to_html(hiki) do |html|
    #      html.traverse do |elm|
    #        if elm.kind_of? HtmlElement and elm.tagname == "a"
    #          elm["class"] = "pdf" if /\.pdf\Z/o =~ elm["href"]
    #        end
    #      end
    #    end
    #
    # and the value of html_str is
    #
    #    <div class="section h2">
    #    <h2> heading
    #    </h2>
    #    <p>
    #    paragraph 1 that contains <a href="http://www.example.org/example.html">a link to a html file</a>
    #    </p>
    #    <p>
    #    paragraph 2 that contains <a class="pdf" href="http://www.example.org/example.pdf">a link to a pdf file</a>
    #    </p>
    #    <!-- end of section h2 -->
    #    </div>
    #
    def self.to_html(hiki_data, &block)
      format(hiki_data, :html, options=nil, &block)
    end

    # Converts <hiki_data> into XHTML1.0
    #
    # You can give a block to this method as in the case of ::to_html, but the parameter to the block is a tree of XhtmlElement objects
    #
    def self.to_xhtml(hiki_data, &block)
      format(hiki_data, :xhtml, options=nil, &block)
    end

    # Converts <hiki_data> into HTML5
    #
    # You can give a block to this method as in the case of ::to_html, but the parameter to the block is a tree of Xhtml5Element objects
    #
    def self.to_html5(hiki_data, &block)
      format(hiki_data, :html5, options=nil, &block)
    end

    # Converts <hiki_data> into plain texts without tags
    #
    def self.to_plain(hiki_data, &block)
      format(hiki_data, :plain, options=nil, &block)
    end

    # Converts <hiki_data> into Markdown
    #
    def self.to_markdown(hiki_data, &block)
      format(hiki_data, :markdown, options=nil, &block)
    end

    # Converts <hiki_data> into GitHub Flavored Markdown
    #
    def self.to_gfm(hiki_data, &block)
      format(hiki_data, :gfm, options=nil, &block)
    end
  end
end

require 'pseudohiki/sinatra_helpers' if defined? Sinatra
