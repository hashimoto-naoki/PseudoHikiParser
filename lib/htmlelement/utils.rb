#!/usr/bin/env ruby

require 'htmlelement'
require 'uri'

class HtmlElement
  module Utils
    class LinkManager
      def initialize(domain_name, from_host_names)
        @domain_name = URI.parse(domain_name)
        @domain_name_re = Regexp.compile(Regexp.escape(domain_name))
        @from_host_names_re = compile_from_names_re(from_host_names)
      end

      def unify_host_names(url)
        url.sub(@from_host_names_re, @domain_name.host)
      end

      def convert_in_relative(url)
        false
      end

      private

      def compile_from_names_re(from_host_names)
        escaped_names = from_host_names.map {|name| Regexp.escape(name) }
        Regexp.compile(escaped_names.join("|"))
      end
    end
  end
end
