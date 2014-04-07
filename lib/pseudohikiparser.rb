#!/usr/bin/env ruby

require "pseudohiki/htmlformat"
require "pseudohiki/plaintextformat"
require "pseudohiki/markdownformat"
require "pseudohiki/version"

module PseudoHiki
  class Format
    Formatter = {}
    PRESET_OPTIONS = {}
    TYPE_TO_FORMATTER = {}

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
      Formatter[preset_options] = formatter.create(options)
      PRESET_OPTIONS[type] = preset_options
      TYPE_TO_FORMATTER[type] = formatter

      class << self
        def format(hiki_data, format_type, options=nil, &block)
          tree = BlockParser.parse(hiki_data)

          if options
            Formatter[[format_type, options]] ||= TYPE_TO_FORMATTER[format_type].create(options)
          else
            Formatter[PRESET_OPTIONS[format_type]]
          end.format(tree).tap do |formatted|
            block.call(formatted) if block
          end.to_s
        end

        def to_html(hiki_data, &block)
          format(hiki_data, :html, options=nil, &block)
        end

        def to_xhtml(hiki_data, &block)
          format(hiki_data, :xhtml, options=nil, &block)
        end

        def to_html5(hiki_data, &block)
          format(hiki_data, :html5, options=nil, &block)
        end

        def to_plain(hiki_data, &block)
          format(hiki_data, :plain, options=nil, &block)
        end

        def to_markdown(hiki_data, &block)
          format(hiki_data, :markdown, options=nil, &block)
        end

        def to_gfm(hiki_data, &block)
          format(hiki_data, :gfm, options=nil, &block)
        end
      end
    end
  end
end
