#!/usr/bin/env ruby

unless //.respond_to? :match?
  class Regexp
    def match?(str)
      self === str
    end
  end
end
