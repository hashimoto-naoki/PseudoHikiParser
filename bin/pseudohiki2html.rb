#!/usr/bin/env ruby

require 'pseudohiki/converter'

options = PseudoHiki::OptionManager.new
options.set_options_from_command_line

if $KCODE
  PseudoHiki::OptionManager::ENCODING_REGEXP.each do |pat, encoding|
    options[:encoding] = encoding if pat =~ $KCODE and not options[:force]
  end
end

unless String.new.respond_to? :encode
  require 'iconv'

  def choose_input_encoding_using_kcode
    PseudoHiki::OptionManager::ENCODING_REGEXP.each do |pat, encoding|
      return PseudoHiki::OptionManager::ENCODING_TO_CHARSET[encoding] if pat =~ $KCODE
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

PseudoHiki::OptionManager.remove_bom
input_lines = ARGF.readlines.map {|line| line.encode(options.charset) }
options.set_options_from_input_file(input_lines)
html = PseudoHiki::PageComposer.new(options).compose_html(input_lines)

options.open_output {|out| out.puts html }
