#!/usr/bin/env ruby

require 'htmlelement'
require 'uri'

class HtmlElement
  module Utils
    def self.collect_elements(tree)
      [].tap do |elms|
        tree.traverse do |elm|
          matched = yield elm
          elms.push elm if matched
        end
      end
    end

    class LinkManager
      SEP = "/"
      SCHEME_RE = /^(https?|ftp):\/\//

      def self.collect_links(tree)
        Utils.collect_elements(tree) do |elm|
          elm.kind_of? HtmlElement and elm.tagname == "a".freeze
        end
      end

      def initialize(domain_name, from_host_names)
        domain_name = domain_name + "/" unless domain_name.end_with?("/")
        @domain_name = URI.parse(domain_name)
        @domain_name_re = Regexp.compile(Regexp.escape(domain_name))
        @from_host_names_re = compile_from_names_re(from_host_names)
      end

      def unify_host_names(url)
        url.sub(@from_host_names_re, @domain_name.host)
      end

      def convert_to_relative_path(url)
        return "./".freeze if default_domain?(url)
        (URI.parse(url) - @domain_name).to_s
      end

      def external_link?(url)
        if SCHEME_RE.match(url)
          URI.parse(url).host != @domain_name.host
        end
      end

      private

      def compile_from_names_re(from_host_names)
        escaped_names = from_host_names.map {|name| Regexp.escape(name) }
        Regexp.compile(escaped_names.join("|"))
      end

      def default_domain?(url)
        url = url + SEP unless url.end_with?(SEP)
        (URI.parse(url) - @domain_name).to_s.empty?
      end
    end
  end
end
