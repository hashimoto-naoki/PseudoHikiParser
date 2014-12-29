PseudoHikiParser
================

PseudoHikiParser is a converter of texts written in a [Hiki](http://hikiwiki.org/en/) like notation, into HTML or other formats. 

I am writing this tool with following objectives in mind,

* provide some additional features that do not exist in the original Hiki notation
  * make the notation more line oriented
  * allow to assign ids to elements such as headings
* support several formats other than HTML
  * The visitor pattern is adopted for the implementation, so you only have to add a visitor class to support a certain format.

And, it would not be compatible with the original Hiki notation.

## License

BSD 2-Clause License

## Installation

```
gem install pseudohikiparser
```

or if you also want to try out experimental features,

```
gem install pseudohikiparser --pre
```

## Usage

### Samples

* [A sample text](https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage.txt) in Hiki notation

And results of conversion

* [HTML 4.01](http://htmlpreview.github.com/?https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage.html)
* [XHTML 1.0](http://htmlpreview.github.com/?https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage_with_toc.html)
* [HTML5](http://htmlpreview.github.com/?https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage_html5_with_toc.html)
* [GFM](https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage.md)

You will find those samples in [develop branch](https://github.com/nico-hn/PseudoHikiParser/tree/develop/samples).

### pseudohiki2html.rb

_(Please note that pseudohiki2html.rb is currently provided as a showcase of PseudoHikiParser, and the options will be continuously changed at this stage of development.)_

After the installation of PseudoHikiParser, you can use a command: **pseudohiki2html.rb**.

Type the following lines at the command prompt:

```
pseudohiki2html.rb <<TEXT
!! The first heading
The first paragraph
TEXT
```

And it will return the following result to stdout:

```html
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head>
<meta content="en" http-equiv="Content-Language">
<meta content="text/html; charset=UTF-8" http-equiv="Content-Type">
<meta content="text/javascript" http-equiv="Content-Script-Type">
<title>-</title>
<link href="default.css" rel="stylesheet" type="text/css">
</head>
<body>
<div class="section h2">
<h2> The first heading
</h2>
<p>
The first paragraph
</p>
<!-- end of section h2 -->
</div>
</body>
</html>
```

And if you specify a file name with `--output` option:

```
pseudohiki2html.rb --output first_example.html <<TEXT
!! The first heading
The first paragraph
TEXT
```

the result will be saved in first\_example.html.

For more options, please try `pseudohiki2html.rb --help`

#### Incompatible changes

From version 0.0.0.9.develop, command line options are renamed as follows:

|old name       |new name         |note                                                       |
|---------------|-----------------|-----------------------------------------------------------|
|-f             |-F               |'-f' is now used as the short version of '--format-version'|
|-h             |-f               |'-h' is now used as the short version of '--help'          |
|--html\_version|--format-version |other formats than html should be supported                |
|--encoding     |--format-encoding|'--encoding' is now used as the long version of '-E' option|
|-              |--encoding       |now same as '-E' option of MRI                             |

### class PseudoHiki::BlockParser

A class method PseudoHiki::BlockParser.parse composes a syntax tree from its input, and a visitor class converts the tree into a certain format.

If you save the lines below as a ruby script and execute it:

```ruby
#!/usr/bin/env ruby

require 'pseudohikiparser'

hiki_text = <<TEXT
!! The first heading
The first paragraph
TEXT

tree = PseudoHiki::BlockParser.parse(hiki_text)
html = PseudoHiki::HtmlFormat.format(tree)
puts html
```

you will get the following output:

```html
<div class="section h2">
<h2> The first heading
</h2>
<p>
The first paragraph
</p>
<!-- end of section h2 -->
</div>
```

In the example above, HtmlFormat is a visitor class that converts the parsed text into HTML 4.01 format.

Other than HtmlFormat, XhtmlFormat, Xhtml5Format, PlainTextFormat and MarkDownFormat are available.

### class PseudoHiki::Format

If you don't need to reuse a tree parsed by PseudoHiki::BlockParser.parse, you can use following class methods of PseudoHiki::Format.

|Method name |Result of conversion    |
|------------|------------------------|
|to\_html    |HTML 4.01               |
|to\_xhtml   |XHTML 1.0               |
|to\_html5   |HTML 5                  |
|to\_plain   |plain text              |
|to\_markdown|Markdown                |
|to\_gfm     |Github Flavored Markdown|

For example, the script below returns the same result as the example of [PseudoHiki::BlockParser](#pseudohiki-blockparser)

```ruby
#!/usr/bin/env ruby

require 'pseudohikiparser'

hiki_text = <<TEXT
!! The first heading
The first paragraph
TEXT

puts PseudoHiki::Format.to_html(hiki_text)
```

## Development status of features from the original [Hiki notation](http://rabbit-shocker.org/en/hiki.html)

* Paragraphs - Usable
* Links
  * WikiNames - Not supported (and would never be)
  * Linking to other Wiki pages - Not supported as well
  * Linking to an arbitrary URL - Maybe usable
* Preformatted text - Usable
* Text decoration - Partly supported
  * Means of escaping tags for inline decorations is only experimetal.
  * The notation for inline literals by backquote tags(``) is converted into not \<tt\> element but \<code\> element.
* Headings - Usable
* Horizontal lines - Usable
* Lists - Usable
* Quotations - Usable
* Definitions - Usable
* Tables - Usable
* Comments - Usable
* Plugins - Not supported (and will not be compatible with the original one)

## Additional Features

### Assigning ids

If you add [name\_of\_id], just after the marks that denote heading or list type items, it becomes the id attribute of resulting html elements. Below is an example.

```
!![heading_id]heading

*[list_id]list
```

will be rendered as

```html
<div class="section h2">
<h2 id="HEADING_ID">heading
</h2>
<ul>
<li id="LIST_ID">list
</li>
</ul>
<!-- end of section h2 -->
</div>
```

### Escaping tags for inline decorations

Tags for inline decorations are escaped when they are enclosed in plugin tags:

```
For example, {{''}} and {{==}} can be escaped.
And {{ {}} and {{} }} should be rendered as two left curly braces and two right curly braces respectively.
```

will be rendered as

```
For example, '' or == can be escaped.
And {{ and }} sould be rendered as two left curly braces and two right curly braces respectively.
```

### Experimental

The following feature is just experimental and available only in [develop branch](https://github.com/nico-hn/PseudoHikiParser/tree/develop).

#### Decorator for blocks

By lines that begin with '//@', you can assign certain attributes to its succeeding block.

For example,

```
//@class[class_name]
!!A section with a class name

paragraph
```

will be renderes as

```html
<div class="class_name">
<h2>A section with a class name
</h2>
<p>
paragraph
</p>
<!-- end of class_name -->
</div>
```

### Not Implemented Yet

## Visitor classes

Please note that some of the following classes are implemented partly or not tested well.

### [HtmlFormat](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/htmlformat.rb#L8), [XhtmlFormat](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/htmlformat.rb#L263)

Their class method (HtmlFormat|XhtmlFormat).format returns a tree of [HtmlElement](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/htmlelement.rb) objects, and you can traverse the tree as in the following example.

```ruby
#!/usr/bin/env ruby

require 'pseudohikiparser'

hiki_text = <<HIKI
!! heading

paragraph 1 that contains [[a link to a html file|http://www.example.org/example.html]]

paragraph 2 that contains [[a link to a pdf file|http://www.example.org/example.pdf]]
HIKI

html = HtmlFormat.format(hiki_text)

html.traverse do |elm|
  if elm.kind_of? HtmlElement and elm.tagname == "a"
    elm["class"] = "pdf" if /\.pdf\Z/o =~ elm["href"]
  end
end

puts html.to_s
```

will print

```html
<div class="section h2">
<h2> heading
</h2>
<p>
paragraph 1 that contains <a href="http://www.example.org/example.html">a link to a html file</a>
</p>
<p>
paragraph 2 that contains <a class="pdf" href="http://www.example.org/example.pdf">a link to a pdf file</a>
</p>
<!-- end of section h2 -->
</div>
```

### [Xhtml5Format](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/htmlformat.rb#L268)

This visitor is for HTML5.

Currently there aren't many differences with [XhtmlFormat](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/htmlformat.rb#L263) exept for the treatment of \<section\> elements.

### [PlainTextFormat](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/plaintextformat.rb)  

This visitor removes markups from its input and returns plain texts. Below are examples

```
:tel:03-xxxx-xxxx
::03-yyyy-yyyy
:fax:03-xxxx-xxxx
```

will be rendered as

```
tel:	03-xxxx-xxxx
	03-yyyy-yyyy
fax:	03-xxxx-xxxx
```

And

```
||cell 1-1||>>cell 1-2,3,4||cell 1-5
||cell 2-1||^>cell 2-2,3 3-2,3||cell 2-4||cell 2-5
||cell 3-1||cell 3-4||cell 3-5
||cell 4-1||cell 4-2||cell 4-3||cell 4-4||cell 4-5
```

will be rendered as

```
cell 1-1	cell 1-2,3,4	==	==	cell 1-5
cell 2-1	cell 2-2,3 3-2,3	==	cell 2-4	cell 2-5
cell 3-1	||	||	cell 3-4	cell 3-5
cell 4-1	cell 4-2	cell 4-3	cell 4-4	cell 4-5
```

### [MarkDownFormat](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/markdownformat.rb)

This visitor is for (Git Flavored) Markdown and just in experimental stage.

The following are a sample script and its output:

```ruby
#!/usr/bin/env ruby

require 'pseudohiki/markdownformat'

md = PseudoHiki::MarkDownFormat.create
gfm = PseudoHiki::MarkDownFormat.create(gfm_style: true)

hiki = <<TEXT
!! The first heading

The first paragraph

||!header 1||!header 2
||''cell 1''||cell2

TEXT

tree = PseudoHiki::BlockParser.parse(hiki)
md_text = md.format(tree).to_s
gfm_text = gfm.format(tree).to_s
puts md_text
puts "--------------------"
puts gfm_text
```

(You will get the following output.)

```
## The first heading

The first paragraph

<table>
<tr><th>header 1</th><th>header 2</th></tr>
<tr><td><em>cell 1</em></td><td>cell2</td></tr>
</table>

--------------------
## The first heading

The first paragraph

|header 1|header 2|
|--------|--------|
|_cell 1_|cell2   |
```

