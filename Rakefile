#!/usr/bin/env ruby

require "bundler/gem_tasks"
#require 'rake/testtask'

task :default => [:test]

task :test do

  test_files = %w(
htmlelement
htmlplugin
htmltemplate
inlineparser
treestack
blockparser
htmlformat
plaintextformat
markdownformat
pseudohikiparser
pseudohiki2html
)
  failed_tests = []

  test_files.each do |libname|
    begin
      if /^1\.8/o =~ RUBY_VERSION
        ruby "-I. -I./lib -rubygems test/test_%s.rb"%[libname]
      else
        ruby "-I. -I./lib test/test_%s.rb"%[libname]
      end
    rescue
      failed_tests.push libname
    end
  end

  unless failed_tests.empty?
    STDERR.puts 'Test(s) for "%s" failed.'%[failed_tests.join(", ")]
  end
end

task :generate_visitor, [:visitor_prefix] do |t, args|
  ruby "tools/visitor_template_generator.rb %s"%args[:visitor_prefix]

  #How to invoke:
  # rake 'generate_visitor[PlainText]'
  #or
  # rake generate_visitor\[PlainText\]
end

#Rake::TestTask.new do |t|
#  t.libs << "test"
#  t.libs << "."
#  t.libs << "./lib"
#  t.test_files = FileList['test/test_*.rb']
#  t.verbose = true
#end
