PseudoHikiParser
================

PseudoHikiParser is a converter of texts written in a [Hiki](http://hikiwiki.org/en/) like notation, into html or other formats. 

Currently, only a limited range of notations can be converted into HTML4 or XHTML1.0.

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
gem install pseudohikiparser --pre
```


## Usage

### Samples

[A sample text](https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage.txt) in Hiki notation and [a result of conversion](http://htmlpreview.github.com/?https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage.html), [another result of conversion](http://htmlpreview.github.com/?https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage_with_toc.html) and [yet another result](http://htmlpreview.github.com/?https://github.com/nico-hn/PseudoHikiParser/blob/develop/samples/wikipage_html5_with_toc.html).

You will find those samples in [develop branch](https://github.com/nico-hn/PseudoHikiParser/tree/develop/samples).


### pseudohiki2html.rb

After the installation of PseudoHikiParser, you could use a command: **pseudohiki2html.rb**.

_Please note that pseudohiki2html.rb is currently provided as a showcase of PseudoHikiParser, and the options will be continuously changed at this stage of development._

Typing the following lines at the command prompt:

```
pseudohiki2html.rb <<TEXT
!! The first heading
The first paragraph
TEXT
```
will return the following result to stdout:

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
the result will be saved in first_example.html.

For more options, please try `pseudohiki2html.rb --help`

### module PseudoHiki

If you save the lines below as a ruby script and execute it:

```ruby
#!/usr/bin/env ruby

require 'pseudohikiparser'

plain = <<TEXT
!! The first heading
The first paragraph
TEXT

tree = PseudoHiki::BlockParser.parse(plain.lines.to_a)
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

Other than PseudoHiki::HtmlFormat, you can choose PseudoHiki::XhtmlFormat, PseudoHiki::Xhtml5Format, PseudoHiki::PlainTextFormat.

## Development status of features from the original [Hiki notation](http://rabbit-shocker.org/en/hiki.html)

* Paragraphs - Usable
* Links
  * WikiNames - Not supported (and would never be)
  * Linking to other Wiki pages - Not supported as well
  * Linking to an arbitrary URL - Maybe usable
* Preformatted text - Usable
* Text decoration - Partly supported
  * Currently, there is no means of escaping tags for inline decorations.
  * The notation with backquote tags(``) for inline literals is not supported.
* Headings - Usable
* Horizontal lines - Usable
* Lists - Usable
* Quotations - Usable
* Definitions - Usable
* Tables - Usable
* Comments - Usable
* Plugins - Not supported (and will not be compatible with the original one)

## Additional Features
### Already Implemented
#### Assigning ids
If you add [name_of_id], just after the marks that denote heading or list type items, it becomes the id attribute of resulting html elements. Below is an example.

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

### Partly Implemented
#### A visitor that removes markups and returns plain texts
The visitor, [PlainTextFormat](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/plaintextformat.rb) is currently available only in the [develop branch](https://github.com/nico-hn/PseudoHikiParser/tree/develop). Below are examples

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
#### A visitor for HTML5
The visitor, [Xhtml5Format](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/htmlformat.rb#L222) is currently available only in the [develop branch](https://github.com/nico-hn/PseudoHikiParser/tree/develop).

#### A visitor for (Git Flavored) Markdown

The visitor, [MarkDownFormat](https://github.com/nico-hn/PseudoHikiParser/blob/develop/lib/pseudohiki/markdownformat.rb) too, is currently available only in the [develop branch](https://github.com/nico-hn/PseudoHikiParser/blob/develop/).

It's just in experimental stage.

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
puts "===================="
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

====================
## The first heading

The first paragraph

|header 1|header 2|
|--------|--------|
|_cell 1_|cell2   |
```

### Not Implemented Yet
