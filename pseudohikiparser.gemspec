# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pseudohiki/version'

Gem::Specification.new do |spec|
  spec.name          = "pseudohikiparser"
  spec.version       = PseudoHiki::VERSION
  spec.required_ruby_version = ">= 1.8.7"
  spec.authors       = ["HASHIMOTO, Naoki"]
  spec.email         = ["hashimoto.naoki@gmail.com"]
  spec.description   = %q{PseudoHikiParser parses texts written in a Hiki like notation, and coverts them into HTML, Markdown or other formats.}
  spec.summary       = %q{PseudoHikiParser: a parser of texts in a Hiki like notation.}
  spec.homepage      = "https://github.com/nico-hn/PseudoHikiParser/wiki"
  spec.license       = "BSD-2-Clause"
  
  spec.files         = [
                        "README.md",
                        "README.ja.md",
                        "LICENSE",
                        "lib/pseudohikiparser.rb",
                        "lib/pseudohiki/treestack.rb",
                        "lib/pseudohiki/inlineparser.rb",
                        "lib/pseudohiki/shim.rb",
                        "lib/pseudohiki/blockparser.rb",
                        "lib/pseudohiki/htmlformat.rb",
                        "lib/pseudohiki/plaintextformat.rb",
                        "lib/pseudohiki/markdownformat.rb",
                        "lib/pseudohiki/version.rb",
                        "lib/pseudohiki/converter.rb",
                        "lib/pseudohiki/utils.rb",
                        "lib/pseudohiki/htmlplugin.rb",
                        "lib/pseudohiki/autolink.rb",
                        "lib/htmlelement.rb",
                        "lib/htmlelement/utils.rb",
                        "lib/htmlelement/htmltemplate.rb"
                       ]
  spec.executables   << "pseudohiki2html"
  spec.test_files    = Dir.glob("test/test_*.rb")
  spec.test_files    << "test/test_data/css/test.css"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 1.3.1"
  spec.add_development_dependency "rubocop", "~> 0.31"
end
