#/usr/bin/env ruby

require 'minitest/autorun'
require 'lib/pseudohiki/blockparser'
require 'lib/pseudohiki/htmlformat'

class TC_HtmlFormat < MiniTest::Unit::TestCase
  include PseudoHiki

  class ::String
    def accept(visitor)
      self.to_s
    end
  end

  def convert_text_to_html(text)
    formatter = HtmlFormat.get_plain
    tree = BlockParser.parse(text.split(/\r?\n/o))
    tree.accept(formatter).to_s
  end

  def test_visit_tree
    text = <<TEXT
!heading1

paragraph1.
paragraph2.
paragraph3.
""citation1
paragraph4.

*list1
*list1-1
**list2
**list2-2
*list3

paragraph5.

!!heading2

paragraph6.
paragraph7.

paragraph8.

!heading3

paragraph9.
TEXT
    html = <<HTML
<div class="section h1">
<h1>heading1</h1>
<p>
paragraph1.paragraph2.paragraph3.</p>
<blockquote>
<p>
citation1</p>
</blockquote>
<p>
paragraph4.</p>
<ul>
<li>list1
<li>list1-1<ul>
<li>list2
<li>list2-2
</ul>

<li>list3
</ul>
<p>
paragraph5.</p>
<div class="section h2">
<h2>heading2</h2>
<p>
paragraph6.paragraph7.</p>
<p>
paragraph8.</p>
<!-- end of section h2 -->
</div>
<!-- end of section h1 -->
</div>
<div class="section h1">
<h1>heading3</h1>
<p>
paragraph9.</p>
<!-- end of section h1 -->
</div>
HTML

    assert_equal(html,convert_text_to_html(text))
  end

  def test_visit_tree_with_inline_elements
    text = <<TEXT
!!heading2

a paragraph with an ''emphasised'' word.
a paragraph with a [[link|http://www.example.org/]].

a paragraph with a ``literal`` word.
TEXT

    html = <<HTML
<div class="section h2">
<h2>heading2</h2>
<p>
a paragraph with an <em>emphasised</em> word.a paragraph with a <a href="http://www.example.org/">link</a>.</p>
<p>
a paragraph with a <code>literal</code> word.</p>
<!-- end of section h2 -->
</div>
HTML

    assert_equal(html,convert_text_to_html(text))
  end

  def test_img
    text = <<TEXT
a paragraph with a normal [[link|http://www.example.org/]]

a paragraph with an [[image|http://www.example.org/image.png]]

a paragraph with a link to an image from [[[[a thumbnail image|image/thumb_nail.png]]|http://www.example.org/image.png]]
TEXT

    html = <<HTML
<p>
a paragraph with a normal <a href="http://www.example.org/">link</a>
</p>
<p>
a paragraph with an <img alt="image" src="http://www.example.org/image.png">

</p>
<p>
a paragraph with a link to an image from <a href="http://www.example.org/image.png"><img alt="a thumbnail image" src="image/thumb_nail.png">
</a>
</p>
HTML


    tree = BlockParser.parse(text)
    assert_equal(html, HtmlFormat.format(tree).to_s)
  end

  def test_plugin
    text = <<TEXT
a paragraph with several plugin tags.
{{''}} should be presented as two quotation marks.
{{ {}} should be presented as two left curly braces.
{{} }} should be presented as two right curly braces.
{{in span}} should be presented as <span>in span</span>.
TEXT

    html = <<HTML
<p>
a paragraph with several plugin tags.
'' should be presented as two quotation marks.
{{ should be presented as two left curly braces.
}} should be presented as two right curly braces.
<span>in span</span> should be presented as &lt;span&gt;in span&lt;/span&gt;.
</p>
HTML

    tree = BlockParser.parse(text)
    assert_equal(html, HtmlFormat.format(tree).to_s)
    assert_equal(html, XhtmlFormat.format(tree).to_s)
  end

  def test_table
    text = <<TEXT
||!col||!^[[col|link]]||>col
||col||col||col
TEXT

    html = <<HTML
<table>
<tr><th>col</th><th rowspan="2"><a href="link">col</a></th><td colspan="2">col</td></tr>
<tr><td>col</td><td>col</td><td>col</td></tr>
</table>
HTML

    assert_equal(html,convert_text_to_html(text))
  end

  def test_dl
    text = <<TEXT
:dt1:dd1
:dt2:dd2
TEXT

    html = <<HTML
<dl>
<dt>dt1</dt>
<dd>dd1</dd>
<dt>dt2</dt>
<dd>dd2</dd>
</dl>
HTML

    assert_equal(html,convert_text_to_html(text))
  end

  def test_table_with_link
    text = <<TEXT
||[[a link|http://www.example.org/]]||another cell
TEXT

    html = <<HTML
<table>
<tr><td><a href="http://www.example.org/">a link</a></td><td>another cell</td></tr>
</table>
HTML
    assert_equal(html,convert_text_to_html(text))
  end

  def test_table_with_emphasis
    text = <<TEXT
||''put'' emphasis on the first word||another cell
TEXT

    html = <<HTML
<table>
<tr><td><em>put</em> emphasis on the first word</td><td>another cell</td></tr>
</table>
HTML
    assert_equal(html,convert_text_to_html(text))
  end

  def test_table_with_strong
    text = <<TEXT
||'''strong''' is used for the first word.||another cell
TEXT

    html = <<HTML
<table>
<tr><td><strong>strong</strong> is used for the first word.</td><td>another cell</td></tr>
</table>
HTML
    assert_equal(html,convert_text_to_html(text))
  end

  def test_table_with_empty_cell_at_the_end
    row = "||cell 1||cell 2||"
    html = <<HTML
<table>
<tr><td>cell 1</td><td>cell 2</td><td></td></tr>
</table>
HTML

# <tr><td>cell 1</td><td>cell 2</td><td>&#160;</td></tr>

    assert_equal(html,convert_text_to_html(row))
  end

  def test_hr
    text = <<TEXT
paragraph

----

paragraph
TEXT

    html = <<HTML
<p>
paragraph</p>
<hr>
<p>
paragraph</p>
HTML

    assert_equal(html,convert_text_to_html(text))
  end

  def test_commentout
    text = <<TEXT
a paragraph.
//a comment
another paragraph.
TEXT

    html = <<HTML
<p>
a paragraph.</p>
<p>
another paragraph.</p>
HTML

    assert_equal(html,convert_text_to_html(text))
  end

  def test_self_format
    text = <<TEXT
a paragraph.

*list

another paragraph.
TEXT

    html = <<HTML
<p>
a paragraph.</p>
<ul>
<li>list
</ul>
<p>
another paragraph.</p>
HTML

    xhtml = <<HTML
<p>
a paragraph.</p>
<ul>
<li>list</li>
</ul>
<p>
another paragraph.</p>
HTML

    tree = BlockParser.parse(text.split(/\r?\n/o))
   assert_equal(html, HtmlFormat.format(tree).to_s)
   assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_listwrapnode
    ul_html = <<HTML
<ul>
<li>ul list
</ul>
HTML

    ol_html = <<HTML
<ol>
<li>ol list
</ol>
HTML

    tree = BlockParser.parse(['*ul list'])
    assert_equal(ul_html, HtmlFormat.format(tree).to_s)
    tree = BlockParser.parse(['#ol list'])
    assert_equal(ol_html, HtmlFormat.format(tree).to_s)
  end

  def test_xhtml
    text = <<TEXT
!heading1

paragraph1.
paragraph2.
""citation1
paragraph3.
----

*list1
*list2
TEXT

    html = <<HTML
<div class="section h1">
<h1>heading1</h1>
<p>
paragraph1.paragraph2.</p>
<blockquote>
<p>
citation1</p>
</blockquote>
<p>
paragraph3.</p>
<hr />
<ul>
<li>list1</li>
<li>list2</li>
</ul>
<!-- end of section h1 -->
</div>
HTML

    formatter = XhtmlFormat.get_plain
    tree = BlockParser.parse(text.split(/\r?\n/o))
    assert_equal(html,tree.accept(formatter).to_s)
  end

  def test_xhtml5
    text = <<TEXT
!heading1

paragraph1.
paragraph2.
""citation1
paragraph3.
----

*list1
*list2
TEXT

    xhtml5 = <<HTML
<section class="h1">
<h1>heading1</h1>
<p>
paragraph1.paragraph2.</p>
<blockquote>
<p>
citation1</p>
</blockquote>
<p>
paragraph3.</p>
<hr />
<ul>
<li>list1</li>
<li>list2</li>
</ul>
<!-- end of h1 -->
</section>
HTML

    tree = BlockParser.parse(text.split(/\r?\n/o))
    assert_equal(xhtml5, Xhtml5Format.format(tree).to_s)
  end

  def test_string_as_input
    text = <<TEXT
!heading1

paragraph1.
paragraph2.
""citation1
paragraph3.
----

*list1
*list2
TEXT

    html = <<HTML
<div class="section h1">
<h1>heading1
</h1>
<p>
paragraph1.
paragraph2.
</p>
<blockquote>
<p>
citation1
</p>
</blockquote>
<p>
paragraph3.
</p>
<hr />
<ul>
<li>list1
</li>
<li>list2
</li>
</ul>
<!-- end of section h1 -->
</div>
HTML

    formatter = XhtmlFormat.get_plain
    tree = BlockParser.parse(text)
    assert_equal(html,tree.accept(formatter).to_s)
  end

  def test_xhtml_list
    text = <<TEXT
*list1(1)
*list2(1)
**list3(2)
**list4(2)
*list5(1)
TEXT

    html = <<HTML
<ul>
<li>list1(1)</li>
<li>list2(1)<ul>
<li>list3(2)</li>
<li>list4(2)</li>
</ul>
</li>
<li>list5(1)</li>
</ul>
HTML

    formatter = XhtmlFormat.get_plain
    tree = BlockParser.parse(text.split(/\r?\n/o))
    assert_equal(html,tree.accept(formatter).to_s)
  end

  def test_xhtml_link
    text = <<TEXT
a line with a [[link|http://www.example.org/]] in it.

*a list item with a [[link|http://www.example.org/]] in it.
TEXT

    html = <<HTML
<p>
a line with a <a href="http://www.example.org/">link</a> in it.</p>
<ul>
<li>a list item with a <a href="http://www.example.org/">link</a> in it.</li>
</ul>
HTML
    formatter = XhtmlFormat.get_plain
    tree = BlockParser.parse(text.split(/\r?\n/o))
    assert_equal(html,tree.accept(formatter).to_s)
  end

  def test_assign_id
    text = <<TEXT
!![h2]heading1

*[l1]list1
TEXT
  html = <<HTML
<div class="section h2">
<h2 id="H2">heading1</h2>
<ul>
<li id="L1">list1
</ul>
<!-- end of section h2 -->
</div>
HTML

  xhtml = <<HTML
<div class="section h2">
<h2 id="H2">heading1</h2>
<ul>
<li id="L1">list1</li>
</ul>
<!-- end of section h2 -->
</div>
HTML

    tree = BlockParser.parse(text.split(/\r?\n/o))
    assert_equal(html, HtmlFormat.format(tree).to_s)
    tree = BlockParser.parse(text.split(/\r?\n/o))
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s) #bug: you should not touch the original tree.
  end

  def test_verbatim
    text = <<TEXT
<<<
a verbatim line.
a verbatim line with <greater than/less than>.
>>>

a normal paragraph.

 another verbatim line with <greater than/less than>.

another normal paragraph.

 the last verbatim line.
TEXT
    xhtml = <<HTML
<pre>
a verbatim line.a verbatim line with &lt;greater than/less than&gt;.</pre>
<p>
a normal paragraph.</p>
<pre>
another verbatim line with &lt;greater than/less than&gt;.</pre>
<p>
another normal paragraph.</p>
<pre>
the last verbatim line.</pre>
HTML

    tree = BlockParser.parse(text.split(/\r?\n/o))
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_tableleaf
    text = "||cell 1-1||!^>>cell 1-2||cell 1-5"
    tree = BlockParser.parse([text])
    assert_equal([[[[["cell 1-1"]], [["cell 1-2"]], [["cell 1-5"]]]]], tree)

    text = "||cell 1-1 is ''emphasised'' partly||!^>>cell 1-2||cell 1-5"
    tree = BlockParser.parse([text])
    assert_equal([[[[["cell 1-1 is "],[["emphasised"]], [" partly"]], [["cell 1-2"]], [["cell 1-5"]]]]], tree)
  end

  def test_quote
    text = <<TEXT
""this line should be enclosed in a p element.
""
""*this line should be a list item.
TEXT

    xhtml = <<HTML
<blockquote>
<p>
this line should be enclosed in a p element.
</p>
<ul>
<li>this line should be a list item.
</li>
</ul>
</blockquote>
HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_verbatim_with_blank_lines
    text = <<TEXT
<<<
a verbatim line with [[a link]]

another verbatim line

 a verbatim line that begins with a space.

the last verbatim line
>>>
TEXT

    text2 = <<TEXT
 a verbatim line with [[a link]]
 
 another verbatim line

  a verbatim line that begins with a space.

 
 the last verbatim line
TEXT


    xhtml = <<HTML
<pre>
a verbatim line with [[a link]]

another verbatim line

 a verbatim line that begins with a space.

the last verbatim line
</pre>
HTML

    input_array = [
                   "<<<\n",
                   "a verbatim line with [[a link]]\n",
                   "\n",
                   "another verbatim line\n",
                   "\n",
                   "the last verbatim line\n",
                   ">>>\n"
                  ]
    tree = BlockParser.parse(text.lines.to_a)
    tree2 = BlockParser.parse(text2.lines.to_a)
#    assert_equal(input_array, text.lines.to_a)
#    assert_equal([], tree2)
#    assert_equal([], tree)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_automatical_link_generation
    text = <<TEXT
a line with a url http://www.example.org/ to test an automatical link generation.
TEXT

    xhtml = <<HTML
<p>
a line with a url <a href="http://www.example.org/">http://www.example.org/</a> to test an automatical link generation.
</p>
HTML
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_no_automatical_link_generation
    text = <<TEXT
a line with a url http://www.example.org/ to test an automatical link generation.
TEXT

    xhtml = <<HTML
<p>
a line with a url http://www.example.org/ to test an automatical link generation.
</p>
HTML
    tree = BlockParser.parse(text.lines.to_a, AutoLink::Off)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_automatical_link_generation_in_verbatim_blocks
    text = <<TEXT
 a line with a url http://www.example.org/ to test an automatical link generation.

 another line with [[link|sample.html]]
TEXT

    xhtml = <<HTML
<pre>
a line with a url <a href="http://www.example.org/">http://www.example.org/</a> to test an automatical link generation.
</pre>
<pre>
another line with [[link|sample.html]]
</pre>
HTML
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_no_automatical_link_generation_in_verbatim_blocks
    text = <<TEXT
 a line with a url http://www.example.org/ to test an automatical link generation.

 another line with [[link|sample.html]]
TEXT

    xhtml = <<HTML
<pre>
a line with a url http://www.example.org/ to test an automatical link generation.
</pre>
<pre>
another line with [[link|sample.html]]
</pre>
HTML
    tree = BlockParser.parse(text.lines.to_a)
    XhtmlFormat.auto_link_in_verbatim = false
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
    XhtmlFormat.auto_link_in_verbatim = true
  end

  def test_temporal_no_automatical_link_generation_in_verbatim_blocks
    text = <<TEXT
 a line with a url http://www.example.org/ to test an automatical link generation.

 another line with [[link|sample.html]]
TEXT

    xhtml = <<HTML
<pre>
a line with a url http://www.example.org/ to test an automatical link generation.
</pre>
<pre>
another line with [[link|sample.html]]
</pre>
HTML
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(xhtml, XhtmlFormat.format(tree, {:auto_link_in_verbatim => false }).to_s)
  end

  def test_temporal_no_automatical_link_generation_in_verbatim_blocks_with_html
    text = <<TEXT
 a line with a url http://www.example.org/ to test an automatical link generation.

 another line with [[link|sample.html]]
TEXT

    xhtml = <<HTML
<pre>
a line with a url http://www.example.org/ to test an automatical link generation.
</pre>
<pre>
another line with [[link|sample.html]]
</pre>
HTML
    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(xhtml, HtmlFormat.format(tree, {:auto_link_in_verbatim => false }).to_s)
  end

  def test_decorator
    text = <<TEXT
//@class[section_type]
!!title of section

a paragraph.

//@class[class_name]
//@id[id_name]
another paragraph.
TEXT

    xhtml = <<HTML
<div class="section_type">
<h2>title of section</h2>
<p>
a paragraph.</p>
<p class="class_name" id="ID_NAME">
another paragraph.</p>
<!-- end of section_type -->
</div>
HTML
    tree = BlockParser.parse(text.lines.to_a.map {|line| line.chomp })
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_decorator_for_table
    text = <<TEXT
//@summary: Summary of the table
||!header 1||! header 2
||cell 1||cell 2
TEXT

    xhtml = <<HTML
<table summary="Summary of the table">
<tr><th>header 1</th><th> header 2</th></tr>
<tr><td>cell 1</td><td>cell 2</td></tr>
</table>
HTML
    tree = BlockParser.parse(text.lines.to_a.map {|line| line.chomp })
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_decorator_for_verbatim
    text = <<TEXT
//@code[ruby]
 def bonjour!
   puts "Bonjour!"
 end
TEXT

    xhtml = <<HTML
<pre>
def bonjour!
  puts &quot;Bonjour!&quot;
end
</pre>
HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_sectioning_node
        text = <<TEXT
! Main title

//@begin[header]
!! first title in header

paragraph

!! second title in header

paragraph2

//@end[header]

!! first subtitle in main part

paragraph3

//@begin[#footer]

paragraph4

//@end[#footer]

TEXT

    expected_html = <<HTML
<div class="section h1">
<h1> Main title
</h1>
<div class="header">
<div class="section h2">
<h2> first title in header
</h2>
<p>
paragraph
</p>
<!-- end of section h2 -->
</div>
<div class="section h2">
<h2> second title in header
</h2>
<p>
paragraph2
</p>
<!-- end of section h2 -->
</div>
<!-- end of header -->
</div>
<div class="section h2">
<h2> first subtitle in main part
</h2>
<p>
paragraph3
</p>
<div class="section" id="footer">
<p>
paragraph4
</p>
<!-- end of footer -->
</div>
<!-- end of section h2 -->
</div>
<!-- end of section h1 -->
</div>
HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_html, XhtmlFormat.format(tree).to_s)
  end

  def test_sectioning_node_for_html5
        text = <<TEXT
! Main title

//@begin[header]
!! first title in header

paragraph

!! second title in header

paragraph2

//@end[header]

!! first subtitle in main part

paragraph3

//@begin[#footer]

paragraph4

//@end[#footer]

TEXT

    expected_html = <<HTML
<section class="h1">
<h1> Main title
</h1>
<header>
<section class="h2">
<h2> first title in header
</h2>
<p>
paragraph
</p>
<!-- end of h2 -->
</section>
<section class="h2">
<h2> second title in header
</h2>
<p>
paragraph2
</p>
<!-- end of h2 -->
</section>
</header>
<section class="h2">
<h2> first subtitle in main part
</h2>
<p>
paragraph3
</p>
<section id="footer">
<p>
paragraph4
</p>
<!-- end of footer -->
</section>
<!-- end of h2 -->
</section>
<!-- end of h1 -->
</section>
HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_html, Xhtml5Format.format(tree).to_s)
  end

  def test_sectioning_node_when_end_tag_is_omitted
        text = <<TEXT
!! First part

paragraph1

//@begin[first_sub_part]
!!! first title in first sub-part

paragraph2

!!! second title in first sub-part

paragraph3

//you should put //@end[first_sub_part] here.

!! Second part

paragraph4

//@begin[#footer]

paragraph5

//@end[#footer]

TEXT

    expected_html = <<HTML
<div class=\"section h2\">
<h2> First part
</h2>
<p>
paragraph1
</p>
<div class=\"section first_sub_part\">
<div class=\"section h3\">
<h3> first title in first sub-part
</h3>
<p>
paragraph2
</p>
<!-- end of section h3 -->
</div>
<div class=\"section h3\">
<h3> second title in first sub-part
</h3>
<p>
paragraph3
</p>
<!-- end of section h3 -->
</div>
<!-- end of section first_sub_part -->
</div>
<!-- end of section h2 -->
</div>
<div class=\"section h2\">
<h2> Second part
</h2>
<p>
paragraph4
</p>
<div class=\"section\" id=\"footer\">
<p>
paragraph5
</p>
<!-- end of footer -->
</div>
<!-- end of section h2 -->
</div>
HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_html, XhtmlFormat.format(tree).to_s)
  end

  def test_sectioning_node_when_end_tag_is_wrongly_placed
        text = <<TEXT
!! First part

paragraph1

//@begin[first_sub_part]
!!! first title in first sub-part

paragraph2

!!! second title in first sub-part

paragraph3

//you should put //@end[first_sub_part] here.

!! Second part

paragraph4


//@end[first_sub_part] this end tag is wrongly placed.

//@begin[#footer]

paragraph5

//@end[#footer]

TEXT

    expected_html = <<HTML
<div class=\"section h2\">
<h2> First part
</h2>
<p>
paragraph1
</p>
<div class=\"section first_sub_part\">
<div class=\"section h3\">
<h3> first title in first sub-part
</h3>
<p>
paragraph2
</p>
<!-- end of section h3 -->
</div>
<div class=\"section h3\">
<h3> second title in first sub-part
</h3>
<p>
paragraph3
</p>
<!-- end of section h3 -->
</div>
<!-- end of section first_sub_part -->
</div>
<!-- end of section h2 -->
</div>
<div class=\"section h2\">
<h2> Second part
</h2>
<p>
paragraph4
</p>
<div class=\"section\" id=\"footer\">
<p>
paragraph5
</p>
<!-- end of footer -->
</div>
<!-- end of section h2 -->
</div>
HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(expected_html, XhtmlFormat.format(tree).to_s)
  end

  def test_comment_out_followed_by_a_verbatim_block
    text = <<TEXT
the first paragraph

//a comment
the second paragraph

//a comment
<<<
the first verbatim line
the second verbatim line
>>>
TEXT

    xhtml = <<HTML
<p>
the first paragraph
</p>
<p>
the second paragraph
</p>
<pre>
the first verbatim line
the second verbatim line
</pre>
HTML

    tree = BlockParser.parse(text.lines.to_a)
    assert_equal(xhtml, XhtmlFormat.format(tree).to_s)
  end

  def test_self_create
    assert_equal(XhtmlFormat, XhtmlFormat.create)
  end
end
