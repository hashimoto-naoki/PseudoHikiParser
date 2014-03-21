#!/usr/bin/env ruby

require 'htmlelement'
require 'pseudohiki/inlineparser'
require 'pseudohiki/htmlformat'
#require('hikiparser/hikiblockparser')

module PseudoHiki
  class HtmlFormat
    class << Formatter[PluginNode]
      def visit(leaf)
        escape_inline_tags(leaf) { HtmlPlugin.new(@element_name,leaf.join).apply }
      end
    end
  end
  
  class HtmlPlugin

    PLUGIN_PAT = /^(\w+)([\s\(]+)/
    NUMBER_RE = /(\d+)/

    def parse(data)
      result = nil
      if PLUGIN_PAT =~ data
        @plugin_name = $1
        @with_paren = true if $2.chomp == "("
        result = data.chomp.sub(PLUGIN_PAT,"")
        result[-1,1] = "" if @with_paren
      else
        @plugin_name = data.chomp
        result = ""
      end
      result
    end

    def initialize(tag_type,parsed_data)
      @tag_type = tag_type
      @plugin_name = nil
      @with_paren = nil
      @data = parse(parsed_data.to_s)
    end
    
    def apply
      self.send @plugin_name
    end

    def html
      #    "<div class='raw-html'>"+HtmlElement.decode(@data)+"</div>"
      HtmlElement.decode(@data).to_s
    end

    #  def inline
    #    lines = HtmlElement.decode(@data).split(/\r*\n/o)
    #    lines.shift if lines.first == ""
    #    HikiBlockParser.new.parse_lines(lines).join
    #  end

    def anchor
      name, anchor_mark = @data.split(/,\s*/o,2)
      anchor_mark = "_" if (anchor_mark.nil? or anchor_mark.empty?)
      HtmlElement.create("a", anchor_mark,
                         "name" => name,
                         "href" => "#"+name)
    end

    def HtmlPlugin.add_chemical_formula(chemical_formula="CO2",en_word="carbon dioxide")
      eval(<<-End)
      def #{chemical_formula.downcase}
        #(display=":cf",second_display=nil)
        display, second_display = @data.split(",\s")
        display = ":cf" unless display
        return [#{chemical_formula.downcase}(display),
          "(",
          #{chemical_formula.downcase}(second_display),
          ")"].join("") if second_display
        case display
        when ":cf"
          "#{chemical_formula}".gsub(NUMBER_RE, "<sub>\\\\1</sub>")
        when ":en"
          "#{en_word}"
        end
      end
      End
    end
    %Q(SF6, sulfur hexafluoride
     CO2, carbon dioxide
     HFC, hydrofluorocarbon
     PFC, perfluorocarbon
     CFC, chlorofluorocarbon
     CH4, methane
     H2O, water
     C2F5Cl, CFC-115, CFC-115).lines.each do |line|
      chemical_formula, en = line.strip.split(/,\s+/)
      add_chemical_formula chemical_formula, en
    end

    def sq
      # I'm wondering if we'd be better to use &sup2; , but when we search by "km2" for example, we may have problem...
      "#{@data}<sup>2</sup>"
    end

    def cb
      # I'm wondering if we'd be better to use &sup3; , but...
      "#{@data}<sup>3</sup>"
    end

    def per
      "#{@data}<sup>-1</sup>"
    end

    def c_degree
      "&deg;C"
    end

    def chemical_formula
      @data.gsub(NUMBER_RE, "<sub>\\1</sub>")
    end

    def iso
      @data.scan(/\A(\d+)([^\d].*)/o) do |data|
        weight, molecule = data
        if self.respond_to? molecule
          return "<sup>#{weight}</sup>" + HtmlPlugin.new("",molecule).apply
        else
          return "<sup>#{weight}</sup>" + molecule
        end
      end
    end

    alias oc c_degree


    def method_missing
      HtmlElement.create(@tag_type, @data, "class" => "plugin")
    end
  end
end

if $0 == __FILE__
  p HtmlPlugin.new("div","html(
<ul>
<li>list
<li>list
</ul>)").apply
  p HtmlPlugin.new("div","inline(
*list
*list
)").apply

p HtmlPlugin.new("div","co2").apply
p HtmlPlugin.new("div","co2 :en").apply
p HtmlPlugin.new("div","cb(3km)").apply
p HtmlPlugin.new("div","per m").apply
p HtmlPlugin.new("div","iso 18co2").apply
end
