#!/usr/bin/env ruby

require 'kconv'

class HtmlElement
  class Children < Array
    alias to_s join

    def traverse(&block)
      each do |child|
        if child.kind_of? HtmlElement or child.kind_of? Children
          child.traverse(&block)
        else
          yield child
        end
      end
    end
  end

  module CHARSET
    EUC_JP = "EUC-JP"
    SJIS = "Shift_JIS"
    UTF8 = "UTF-8"
    LATIN1 = "ISO-8859-1"
  end

  @doctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">'.gsub(/\r?\n/o, $/) + $/

  ESC = {
    '&' => '&amp;',
    '"' => '&quot;',
    '<' => '&lt;',
    '>' => '&gt;'
  }

  DECODE = ESC.invert
  @char_entity_pat = /#{DECODE.keys.join("|")}/

  HTML5_TAGS = %w(article section hgroup aside nav menu header footer figure details legend)

  ELEMENT_TYPES = {
    :BLOCK => %w(html body div table colgroup thead tbody ul ol dl head p pre blockquote style),
    :HEADING_TYPE_BLOCK => %w(dt dd tr title h1 h2 h3 h4 h5 h6),
    :LIST_ITEM_TYPE_BLOCK => %w(li col),
    :EMPTY_BLOCK => %w(img meta link base input hr)
  }

  ELEMENTS_FORMAT = {
    :INLINE => "<%1$s%2$s>%3$s</%1$s>",
    :BLOCK => "<%1$s%2$s>#{$/}%3$s</%1$s>#{$/}",
    :HEADING_TYPE_BLOCK => "<%1$s%2$s>%3$s</%1$s>#{$/}",
    :LIST_ITEM_TYPE_BLOCK => "<%1$s%2$s>%3$s#{$/}",
    :EMPTY_BLOCK => "<%1$s%2$s>#{$/}"
  }

  attr_reader :tagname
  attr_accessor :parent, :children

  def self.doctype(encoding="UTF-8")
    format(@doctype, encoding)
  end

  def self.create(tagname, content=nil, attributes={})
    if self::HTML5_TAGS.include? tagname
      attributes["class"] = tagname
      tagname = "div"
    end
    new(tagname, content, attributes)
  end

  def self.comment(content)
    "<!-- #{content} -->#{$/}"
  end

  def self.urlencode(str)
    str.toutf8.gsub(/[^\w\.\-]/o) {|utf8_char| utf8_char.unpack("C*").map {|b| format('%%%02X', b) }.join }
  end

  def self.urldecode(str)
    utf = str.gsub(/%\w\w/) {|ch| [ch[-2, 2]].pack('H*') }.toutf8
    return utf.tosjis if $KCODE =~ /^s/io
    return utf.toeuc if $KCODE =~ /^e/io
    utf
  end

  def self.assign_tagformats
    tagformats = Hash.new(ELEMENTS_FORMAT[:INLINE])
    self::ELEMENT_TYPES.each do |type, names|
      names.each {|name| tagformats[name] = self::ELEMENTS_FORMAT[type] }
    end
    tagformats[""] = "%s%s%s"
    tagformats
  end

  def self.escape(str)
    str.gsub(/[&"<>]/o) {|pat| ESC[pat] }
  end

  def self.decode(str)
    str.gsub(@char_entity_pat) {|ent| DECODE[ent] }
  end

  TagFormats = assign_tagformats

  def initialize(tagname, content=nil, attributes={})
    @parent = nil
    @tagname = tagname
    @children = Children.new
    @children.push content if content
    @attributes = attributes
    @end_comment_not_added = true
  end

  def empty?
    @children.empty?
  end

  def push(child)
    @children.push child
    child.parent = self if child.kind_of? HtmlElement
    self
  end

  def pop
    @children.pop
  end

  def []=(attribute, value)
    @attributes[attribute] = value
  end

  def [](attribute)
    @attributes[attribute]
  end

  def format_attributes
    @attributes.collect do |attr, value|
      " #{attr}=\"#{HtmlElement.escape(value.to_s)}\""
    end.sort.join
  end
  private :format_attributes

  def add_end_comment_for_div_or_section
    if @tagname == "div" or @tagname == "section" and @end_comment_not_added
      id_or_class = self["id"] || self["class"]
      push HtmlElement.comment("end of #{id_or_class}") if id_or_class
      @end_comment_not_added = false
    end
  end

  def to_s
    add_end_comment_for_div_or_section
    format(self.class::TagFormats[@tagname], @tagname, format_attributes, @children)
  end
  alias to_str to_s

  def traverse(&block)
    yield self
    @children.traverse(&block)
  end
end

class XhtmlElement < HtmlElement
  @doctype = '<?xml version="1.0" encoding="%s"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'.gsub(/\r?\n/o, $/) + $/

  ELEMENTS_FORMAT = superclass::ELEMENTS_FORMAT.dup
  ELEMENTS_FORMAT[:LIST_ITEM_TYPE_BLOCK] = "<%1$s%2$s>%3$s</%1$s>#{$/}"
  ELEMENTS_FORMAT[:EMPTY_BLOCK] = "<%1$s%2$s />#{$/}"

  TagFormats = assign_tagformats
end

class Xhtml5Element < XhtmlElement
  @doctype = '<?xml version="1.0" encoding="%s"?>
<!DOCTYPE html>'.gsub(/\r?\n/o, $/) + $/

  ELEMENT_TYPES = superclass::ELEMENT_TYPES.dup
  ELEMENT_TYPES[:BLOCK] = superclass::ELEMENT_TYPES[:BLOCK] + superclass::HTML5_TAGS
  HTML5_TAGS = %w(main)

  TagFormats = assign_tagformats
end
