#/usr/bin/env ruby

require 'test/unit'
require 'htmlelement/htmltemplate'

class TC_HtmlTemplate < Test::Unit::TestCase

  def test_new
    html_result = <<HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd"><html>
<head>
<meta content="en" http-equiv="Content-Language">
<meta content="text/html; charset=UTF-8" http-equiv="Content-Type">
<meta content="text/javascript" http-equiv="Content-Script-Type">
<title></title>
<link href="default.css" rel="stylesheet" type="text/css">
</head>
<body>
</body>
</html>
HTML

    assert_equal(html_result, HtmlTemplate.new.to_s)
  end

  def test_charset
    sjis_result =<<HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd"><html>
<head>
<meta content="ja" http-equiv="Content-Language">
<meta content="text/html; charset=Shift_JIS" http-equiv="Content-Type">
<meta content="text/javascript" http-equiv="Content-Script-Type">
<title></title>
<link href="default.css" rel="stylesheet" type="text/css">
</head>
<body>
</body>
</html>
HTML

    euc_jp_result = <<HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd"><html>
<head>
<meta content="ja" http-equiv="Content-Language">
<meta content="text/html; charset=EUC-JP" http-equiv="Content-Type">
<meta content="text/javascript" http-equiv="Content-Script-Type">
<title></title>
<link href="default.css" rel="stylesheet" type="text/css">
</head>
<body>
</body>
</html>
HTML

    html = HtmlTemplate.new

    html.sjis!
    assert_equal(sjis_result, html.to_s)

    html.euc_jp!
    assert_equal(euc_jp_result, html.to_s)

    html.charset = 'Shift_JIS'
    assert_equal(sjis_result, html.to_s)
  end

  def test_base
    html_result = <<HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd"><html>
<head>
<meta content="en" http-equiv="Content-Language">
<meta content="text/html; charset=UTF-8" http-equiv="Content-Type">
<meta content="text/javascript" http-equiv="Content-Script-Type">
<title></title>
<link href="default.css" rel="stylesheet" type="text/css">
<base href="/base/path">
</head>
<body>
</body>
</html>
HTML

    html = HtmlTemplate.new
    html.base = '/base/path'
    assert_equal(html_result, html.to_s)
  end
end
