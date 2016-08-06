#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/htmlelement'

class TC_HtmlElement < MiniTest::Unit::TestCase
  def test_pop
    section = HtmlElement.create("section")
    h1 = HtmlElement.create("h1")
    section.push h1
    assert_equal(section.children[0], h1)
    assert_equal(section, h1.parent)
    section.pop
    assert(section.children.empty?)
    assert_nil(h1.parent)
  end

  def test_unshift
    section = HtmlElement.create("section")
    paragraph = HtmlElement.create("p", "paragraph")
    h1 = HtmlElement.create("h1", "title")
    section.push paragraph
    assert_equal(1, section.children.length)
    section.unshift h1
    assert_equal(2, section.children.length)
    assert_equal(h1, section.children[0])
  end

  def test_shift
    section = HtmlElement.create("section")
    paragraph = HtmlElement.create("p", "paragraph")
    h1 = HtmlElement.create("h1", "title")
    section.push h1
    section.push paragraph
    assert_equal(section.children[0], h1)
    assert_equal(section, h1.parent)
    section.shift
    refute(section.children.include?(h1))
    assert_nil(h1.parent)
  end

  def test_format_attributes
    a = HtmlElement.create("a")
    a['href'] = "http://www.example.net/example.cgi&param=value"
    assert_equal('<a href="http://www.example.net/example.cgi&amp;param=value"></a>', a.to_s)
  end

  def test_empty_elements
    xhtml_img = XhtmlElement.create("img")
    assert_equal('<img />'+$/, xhtml_img.to_s)

    img = HtmlElement.create("img")
    assert_equal('<img>'+$/, img.to_s)

    xhtml_img = XhtmlElement.create("img")
    assert_equal('<img />'+$/, xhtml_img.to_s)

    img = HtmlElement.create("img")
    assert_equal('<img>'+$/, img.to_s)
  end

  def test_urlencode
    utf_str = "\xe3\x83\x86\xe3\x82\xb9\xe3\x83\x88" # test in utf8 katakata
    sjis_str = "\x83\x65\x83\x58\x83\x67" # test in sjis katakana
    euc_jp_str = "\xa5\xc6\xa5\xb9\xa5\xc8" # test in euc-jp katakana
    assert_equal("%E3%83%86%E3%82%B9%E3%83%88", HtmlElement.urlencode(utf_str))
    assert_equal("%E3%83%86%E3%82%B9%E3%83%88", HtmlElement.urlencode(sjis_str))
    assert_equal("%E3%83%86%E3%82%B9%E3%83%88", HtmlElement.urlencode(euc_jp_str))
  end

  def test_urldecode
    urlencoded_str = "%E3%83%86%E3%82%B9%E3%83%88"
    assert_equal("\xe3\x83\x86\xe3\x82\xb9\xe3\x83\x88", HtmlElement.urldecode(urlencoded_str))
  end

  def test_doc_type
    html_doctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

    assert_equal(html_doctype, HtmlElement.doctype("EUC-JP"))


    xhtml_doctype = '<?xml version="1.0" encoding="EUC-JP"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

    assert_equal(xhtml_doctype, XhtmlElement.doctype("EUC-JP"))

    xhtml_default_doctype = '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

    assert_equal(xhtml_default_doctype, XhtmlElement.doctype)

    html5_doctype = '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>'.split(/\r?\n/o).join($/)+"#{$/}"

    assert_equal(html5_doctype, Xhtml5Element.doctype)
  end

  def test_html5_elements
    html_section = <<SECTION
<div class="section">
<!-- end of section -->
</div>
SECTION

    html_section = html_section.split(/\r?\n/o).join($/)+"#{$/}"

    assert_equal(html_section, HtmlElement.create("section").to_s)

    html5_section = <<SECTION
<section>
</section>
SECTION

    html5_section = html5_section.split(/\r?\n/o).join($/)+"#{$/}"

    assert_equal(html5_section, Xhtml5Element.create("section").to_s)
  end

  def test_traverse
    html, head, meta, body, h1 = %w(html head meta body h1).map {|tagname| HtmlElement.create(tagname) }
    h1_content = "heading 1"

    html.push head
    head.push meta
    html.push body
    body.push h1
    h1.push h1_content

    elements = []
    html.traverse {|elm| elements.push elm }

    assert_equal([html, head, meta, body, h1, h1_content], elements)
  end
end
