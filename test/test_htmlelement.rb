#/usr/bin/env ruby

require 'test/unit'
require 'lib/htmlelement'

class TC_HtmlElement < Test::Unit::TestCase

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
end
