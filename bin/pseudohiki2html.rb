#!/usr/bin/env ruby

require 'pseudohiki/converter'

options = PseudoHiki::OptionManager.new
options.set_options_from_command_line

if $KCODE
  PseudoHiki::OptionManager::ENCODING_REGEXP.each do |pat, encoding|
    options[:encoding] = encoding if pat =~ $KCODE and not options[:force]
  end
end

PseudoHiki::OptionManager.remove_bom
input_lines = ARGF.readlines.map {|line| line.encode(options.charset) }
options.set_options_from_input_file(input_lines)
html = PseudoHiki::PageComposer.new(options).compose_html(input_lines)

options.open_output {|out| out.puts html }
