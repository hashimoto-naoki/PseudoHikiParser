#!/usr/bin/env ruby

require 'htmlelement'
require 'uri'

class HtmlElement
  module Utils
    class LinkManager
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
        (URI.parse(url) - @domain_name).to_s
      end

      private

      def compile_from_names_re(from_host_names)
        escaped_names = from_host_names.map {|name| Regexp.escape(name) }
        Regexp.compile(escaped_names.join("|"))
      end
    end
  end
end
