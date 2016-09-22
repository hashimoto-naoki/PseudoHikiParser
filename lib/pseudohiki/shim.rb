#!/usr/bin/env ruby

unless //.respond_to? :match?
  class Regexp
    def match?(str)
      self === str
    end
  end
end

unless String.new.respond_to? :encode
  require 'iconv'

  class String
    def choose_input_encoding_using_kcode
      PseudoHiki::OptionManager::ENCODING_REGEXP.each do |pat, encoding|
        return PseudoHiki::OptionManager::ENCODING_TO_CHARSET[encoding] if pat.match? $KCODE
      end
      HtmlElement::CHARSET::UTF8
    end
    private :choose_input_encoding_using_kcode

    def encode(to, from=choose_input_encoding_using_kcode)
      iconv = Iconv.new(to, from)
      str = iconv.iconv(self)
      str << iconv.iconv(nil)
    end
    public :encode
  end
end
