#!/usr/bin/env ruby

require 'kconv'

class HtmlElement

  class Children < Array

    def to_s
      self.join("")
    end
  end

  module CHARSET
    EUC_JP = "EUC-JP"
    SJIS = "Shift_JIS"
    UTF8 = "UTF-8"
    LATIN1 = "ISO-8859-1"
  end

  Html4Doctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

  Xhtml1Doctype = '<?xml version="1.0" encoding="%s"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"



  ESC = {
    '&' => '&amp;',
    '"' => '&quot;',
    '<' => '&lt;',
    '>' => '&gt;'
  }

  DECODE = ESC.invert
  CharEntityPat = /#{DECODE.keys.join("|")}/
  
  TagFormats = Hash.new("<%s%s>%s</%s>")
  
  [[%w(html body div table colgroup thead tbody ul ol dl head p pre blockquote style),"<%s%s>#{$/}%s</%s>#{$/}"],
   [%w(dt dd tr title h1 h2 h3 h4 h5 h6),"<%s%s>%s</%s>#{$/}"],
   [%w(li col),"<%s%s>%s#{$/}"],
   [%w(img meta link base input hr), "<%s%s>#{$/}"]
  ].each do |tags,format|
    tags.each do |tag|
      TagFormats[tag] = format
    end
  end
  
  TagFormats[""] = "%s%s%s"

  Html5Tags = %w(article section hgroup aside nav menu header footer menu figure details legend)
  XhtmlTagFormats = TagFormats.dup
  XhtmlTagFormats.each do |key, value|
    case value
    when "<%s%s>%s#{$/}"
      XhtmlTagFormats[key] = "<%s%s>%s</%s>#{$/}"
    when "<%s%s>#{$/}"
      XhtmlTagFormats[key] = "<%s%s />#{$/}"
    end
  end

  def HtmlElement.escape(str)
    str.gsub(/[&"<>]/on) {|pat| ESC[pat] }
  end

  def HtmlElement.decode(str)
    str.gsub(CharEntityPat) {|ent| DECODE[ent]}
  end

  def initialize(tagname)
    @parent = nil
    @tagname = tagname
    @children = Children.new
    @attributes = {}
    @end_comment_not_added = true
  end

  attr_reader :tagname
  attr_accessor :parent, :children

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
    end.sort.join("")
  end
  private :format_attributes

  def add_end_comment_for_div
    if @tagname == "div" and @end_comment_not_added
      id_or_class = self["id"]||self["class"]
      self.push HtmlElement.comment("end of #{id_or_class}") if id_or_class
      @end_comment_not_added = false
    end
  end

  def to_s
    add_end_comment_for_div
    TagFormats[@tagname]%[@tagname, format_attributes, @children, @tagname]
  end

  def self.doctype(encoding="euc-jp")
    Html4Doctype
  end
  alias to_str to_s

  def HtmlElement.comment(content)
    "<!-- #{content} -->#{$/}"
  end

  def configure
    yield self
    self
  end
      
  def self.create(tagname,content=nil)
    if Html5Tags.include? tagname
      tag = self.new("div")
      tag["class"] = tagname
    else
      tag = self.new(tagname)
    end
    tag.push content if content
    yield tag if block_given?
    tag
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
end
  
def Tag(tagname,content=nil)
  HtmlElement.create(tagname,content)
end

class XhtmlElement < HtmlElement

  def to_s
    add_end_comment_for_div
    XhtmlTagFormats[@tagname]%[@tagname, format_attributes, @children, @tagname]
  end

  def self.doctype(encoding="euc-jp")
    Xhtml1Doctype%[encoding]
  end

  alias to_str to_s
end
