#!/usr/bin/env ruby

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
plaintextformat
)
  failed_tests = []

  test_files.each do |libname|
    begin
      ruby "-I. -I./lib test/test_%s.rb"%[libname]
    rescue
      failed_tests.push libname
    end
  end

  unless failed_tests.empty?
    STDERR.puts 'Test(s) for "%s" failed.'%[failed_tests.join(", ")]
  end
end

#Rake::TestTask.new do |t|
#  t.libs << "test"
#  t.libs << "."
#  t.libs << "./lib"
#  t.test_files = FileList['test/test_*.rb']
#  t.verbose = true
#end
