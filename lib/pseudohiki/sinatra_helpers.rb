#!/usr/bin/env ruby

begin
  module Sinatra
    module PseudoHikiParserHelpers
      XHTML5_CONTENT_TYPE = 'application/xhtml+xml'
      def phiki(hiki_data, &block)
        case content_type
        when XHTML5_CONTENT_TYPE
          PseudoHiki::Format.to_html5(hiki_data, &block)
        else
          PseudoHiki::Format.to_xhtml(hiki_data, &block)
        end
      end
    end

    class Base
      helpers PseudoHikiParserHelpers
    end
  end
rescue
  #Sinatra is not available
end
