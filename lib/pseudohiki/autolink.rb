#!/usr/bin/env ruby

require 'pseudohiki/blockparser'

module PseudoHiki
  module AutoLink
    # WIKI_NAME_RE is borrowed from hikidoc
    WIKI_NAME_RE = /\^?\b(?:[A-Z]+[a-z\d]+){2,}\b/
    ESCAPE_CHAR = "^"

    class WikiName
      @default_options = {
        :url => true,
        :wiki_name => true,
        :escape_wiki_name => true
      }

      def self.default_options
        @default_options
      end

      def initialize(options={})
        @options = WikiName.default_options.dup.merge!(options)
        @auto_linker = @options[:url] ? URL : Off
      end

      def auto_link_url?
        @options[:url]
      end

      def escaped_wiki_name?(wiki_name)
        @options[:escape_wiki_name] and wiki_name.start_with?(ESCAPE_CHAR)
      end

      def in_link_tag?(preceding_str)
        URL.in_link_tag?(preceding_str)
      end

      def add_tag(url)
        if escaped_wiki_name?(url)
          url[1..-1]
        elsif url.start_with?(ESCAPE_CHAR)
          "^[[#{url[1..-1]}]]"
        else
          "[[#{url}]]"
        end
      end

      def link_wiki_name(line)
        return line if not WIKI_NAME_RE.match? line or VERBATIM_LEAF_HEAD_RE.match? line
        line.gsub(WIKI_NAME_RE) {|url| in_link_tag?($`) ? url : add_tag(url) }
      end

      def link(line)
        line = @auto_linker.link(line)
        @options[:wiki_name] ? link_wiki_name(line) : line
      end
    end
  end
end
