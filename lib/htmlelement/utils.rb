#!/usr/bin/env ruby

require 'htmlelement'
require 'uri'

class HtmlElement
  module Utils
    class LinkManager
      def initialize(domain_name, dir_in_domain, from_names)
      end

      def unify_domain_names(url)
        false
      end

      def convert_in_relative(url)
        false
      end
    end
  end
end
