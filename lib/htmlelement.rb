#!/usr/bin/env ruby

require 'kconv'

class HtmlElement
  class Children < Array
    alias to_s join
  end

  module CHARSET
    EUC_JP = "EUC-JP"
    SJIS = "Shift_JIS"
    UTF8 = "UTF-8"
    LATIN1 = "ISO-8859-1"
  end

  DOCTYPE = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

  ESC = {
    '&' => '&amp;',
    '"' => '&quot;',
    '<' => '&lt;',
    '>' => '&gt;'
  }

  DECODE = ESC.invert
  CharEntityPat = /#{DECODE.keys.join("|")}/
  
  Html5Tags = %w(article section hgroup aside nav menu header footer figure details legend)

  ELEMENT_TYPES = {
    :BLOCK => %w(html body div table colgroup thead tbody ul ol dl head p pre blockquote style),
    :HEADING_TYPE_BLOCK => %w(dt dd tr title h1 h2 h3 h4 h5 h6),
    :LIST_ITEM_TYPE_BLOCK => %w(li col),
    :EMPTY_BLOCK => %w(img meta link base input hr)
  }
  
  ELEMENTS_FORMAT = {
    :INLINE => "<%s%s>%s</%s>",
    :BLOCK => "<%s%s>#{$/}%s</%s>#{$/}",
    :HEADING_TYPE_BLOCK => "<%s%s>%s</%s>#{$/}",
    :LIST_ITEM_TYPE_BLOCK => "<%s%s>%s#{$/}",
    :EMPTY_BLOCK => "<%s%s>#{$/}"
  }

  attr_reader :tagname
  attr_accessor :parent, :children

  def self.doctype(encoding="UTF-8")
    self::DOCTYPE%[encoding]
  end

  def self.create(tagname, content=nil, attributes={})
    if self::Html5Tags.include? tagname
      attributes["class"] = tagname
      tagname = "div"
    end
    self.new(tagname, content, attributes)
  end

  def HtmlElement.comment(content)
    "<!-- #{content} -->#{$/}"
  end

  def HtmlElement.urlencode(str)
    str.toutf8.gsub(/[^\w\.\-]/n) {|ch| format('%%%02X', ch[0]) }
  end

  def HtmlElement.urldecode(str)
    utf = str.gsub(/%\w\w/) {|ch| [ch[-2,2]].pack('H*') }
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

  def HtmlElement.escape(str)
    str.gsub(/[&"<>]/on) {|pat| ESC[pat] }
  end

  def HtmlElement.decode(str)
    str.gsub(CharEntityPat) {|ent| DECODE[ent]}
  end

  TagFormats = self.assign_tagformats

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
    @attributes.collect do |attr,value|
      ' %s="%s"'%[attr,HtmlElement.escape(value.to_s)]
    end.sort.join
  end
  private :format_attributes

  def add_end_comment_for_div_or_section
    if @tagname == "div" or @tagname == "section" and @end_comment_not_added
      id_or_class = self["id"]||self["class"]
      self.push HtmlElement.comment("end of #{id_or_class}") if id_or_class
      @end_comment_not_added = false
    end
  end

  def to_s
    add_end_comment_for_div_or_section
    self.class::TagFormats[@tagname]%[@tagname, format_attributes, @children, @tagname]
  end
  alias to_str to_s
end
  
class XhtmlElement < HtmlElement
  DOCTYPE = '<?xml version="1.0" encoding="%s"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

  ELEMENTS_FORMAT = self.superclass::ELEMENTS_FORMAT.dup
  ELEMENTS_FORMAT[:LIST_ITEM_TYPE_BLOCK] = "<%s%s>%s</%s>#{$/}"
  ELEMENTS_FORMAT[:EMPTY_BLOCK] = "<%s%s />#{$/}"

  TagFormats = self.assign_tagformats
end

class Xhtml5Element < XhtmlElement
  DOCTYPE = '<?xml version="1.0" encoding="%s"?>
<!DOCTYPE html>'.split(/\r?\n/o).join($/)+"#{$/}"

  ELEMENT_TYPES = self.superclass::ELEMENT_TYPES.dup
  ELEMENT_TYPES[:BLOCK] = self.superclass::ELEMENT_TYPES[:BLOCK] + self.superclass::Html5Tags
  Html5Tags = %w(main)

  TagFormats = self.assign_tagformats
end
