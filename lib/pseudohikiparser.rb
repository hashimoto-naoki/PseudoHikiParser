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
    @@formatter = {}
    @@preset_options = {}
    @@type_to_formatter = {}

    [
     [:html, HtmlFormat, nil],
     [:xhtml, XhtmlFormat, nil],
     [:html5, Xhtml5Format, nil],
     [:plain, PlainTextFormat, {:verbose_mode => false }],
     [:plain_verbose, PlainTextFormat, {:verbose_mode => true }],
     [:markdown, MarkDownFormat, { :strict_mode=> false, :gfm_style => false }],
     [:gfm, MarkDownFormat, { :strict_mode=> false, :gfm_style => true }]
    ].each do |type, formatter, options|
      preset_options = [type, nil]
      @@formatter[preset_options] = formatter.create(options)
      @@preset_options[type] = preset_options
      @@type_to_formatter[type] = formatter
    end

    class << self
      # Converts <hiki_data> into a format specified by <format_type>
      #
      # <hiki_data> should be a string or an array of strings
      #
      # Options for <format_type> are:
      # [:html] HTML4.1
      # [:xhtml] XHTML1.0
      # [:html5] HTML5
      # [:plain] remove all of tags
      # [:plain_verbose] similar to :plain, but certain information such as urls in link tags will be kept
      # [:markdown] Markdown
      # [:gfm] GitHub Flavored Markdown
      #
      def format(hiki_data, format_type, options=nil, &block)
        tree = BlockParser.parse(hiki_data)

        if options
          @@formatter[[format_type, options]] ||= @@type_to_formatter[format_type].create(options)
        else
          @@formatter[@@preset_options[format_type]]
        end.format(tree).tap do |formatted|
          block.call(formatted) if block
        end.to_s
      end

      # Converts <hiki_data> into HTML4.1
      #
      #
      def to_html(hiki_data, &block)
        format(hiki_data, :html, options=nil, &block)
      end

      # Converts <hiki_data> into XHTML1.0
      #
      def to_xhtml(hiki_data, &block)
        format(hiki_data, :xhtml, options=nil, &block)
      end

      # Converts <hiki_data> into HTML5
      #
      def to_html5(hiki_data, &block)
        format(hiki_data, :html5, options=nil, &block)
      end

      # Converts <hiki_data> into plain texts without tags
      #
      def to_plain(hiki_data, &block)
        format(hiki_data, :plain, options=nil, &block)
      end

      # Converts <hiki_data> into Markdown
      #
      def to_markdown(hiki_data, &block)
        format(hiki_data, :markdown, options=nil, &block)
      end

      # Converts <hiki_data> into GitHub Flavored Markdown
      #
      def to_gfm(hiki_data, &block)
        format(hiki_data, :gfm, options=nil, &block)
      end
    end
  end
end
