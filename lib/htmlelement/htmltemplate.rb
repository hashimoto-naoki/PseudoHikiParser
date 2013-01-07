#!/usr/bin/env ruby

require 'htmlelement'

class HtmlTemplate

  META_CHARSET = "text/html; charset=%s"
  LANGUAGE = Hash.new("en")
  LANGUAGE[HtmlElement::CHARSET::EUC_JP] = "ja"
  LANGUAGE[HtmlElement::CHARSET::SJIS] = "ja"
  ELEMENT = { self => HtmlElement }

  def initialize(charset=ELEMENT[self.class]::CHARSET::UTF8, language="en", css_link="default.css", base_uri=nil)
    @html = ELEMENT[self.class].create("html")
    @head = ELEMENT[self.class].create("head")
    @charset = charset
    @content_language = create_meta("Content-Language", language)
    if base_uri
      @base = ELEMENT[self.class].create("base") do |base|
        base["href"] = base_uri
      end
    else
      @base = ""
    end
    @content_type = create_meta("Content-Type",META_CHARSET%[charset])
    @content_style_type = create_meta("Content-Style-Type","text/css")
    @content_script_type = create_meta("Content-Script-Type","text/javascript")
    @default_css_link = create_css_link(css_link)
    @title = nil
    @title_element = ELEMENT[self.class].create("title")
    @body = ELEMENT[self.class].create("body")
    @html.push @head
    @html.push @body
    [ @content_language,
      @content_type,
      @content_sytle_type,
      @content_script_type,
      @title_element,
      @base,
      @default_css_link
    ].each do |element|
      @head.push element
    end
  end
  attr_reader :title

  def charset=(charset_name)
    @charset=charset_name
    @content_language["content"] = LANGUAGE[@charset]
    @content_type["content"] = META_CHARSET%[charset_name]
  end

  def language=(language)
    @content_language["content"] = language
  end

  def base=(base_uri)
    if @base.empty?
      @base = ELEMENT[self.class].create("base") do |base|
        base["href"] = base_uri
      end
      @head.push @base
    else
      @base["href"] = base_uri
    end
  end

  def add_css_file(file_path)
    @head.push create_css_link(file_path)
  end

  def default_css=(file_path)
    @default_css_link["href"] = file_path
  end

  def title=(title)
    @title_element.pop until @title_element.empty?
    @title = title
    @title_element.push title
  end

  def push(element)
    @body.push element
  end

  def euc_jp!
    self.charset = ELEMENT[self.class]::CHARSET::EUC_JP
  end

  def sjis!
    self.charset = ELEMENT[self.class]::CHARSET::SJIS
  end

  def utf8!
    self.charset = ELEMENT[self.class]::CHARSET::UTF8
  end

  def latin1!
    self.charset = ELEMENT[self.class]::CHARSET::LATIN1
  end

  def to_s
    [ELEMENT[self.class].doctype(@charset),
      @html].join("")
  end

  private

  def create_meta(type,content)
    ELEMENT[self.class].create("meta") do |meta| 
      meta["http-equiv"] = type
      meta["content"] = content
    end
  end

  def create_css_link(file_path)
    ELEMENT[self.class].create("link") do |link|
      link["rel"] = "stylesheet"
      link["type"] = "text/css"
      link["href"] = file_path
    end
  end
end

class XhtmlTemplate < HtmlTemplate
  ELEMENT[self] = XhtmlElement

  def initialize(*params)
    super(*params)
    @html['xmlns'] = 'http://www.w3.org/1999/xhtml'
  end
end
