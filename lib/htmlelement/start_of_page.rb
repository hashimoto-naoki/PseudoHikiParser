#!/usr/bin/env ruby

class HtmlElement

  def self.create_start_of_page(label, dest)
    self.create("div").tap do |to|
      to["class"] = "to_top"
      a = self.create("a", label)
      a["href"] = dest
      to.push a
    end
  end

  def self.set_start_of_page(label = "Start of page", dest = "#start_of_page")
    @@start_of_page = self.create_start_of_page(label, dest)
  end

  self.set_start_of_page

  def add_end_comment_for_div_or_section
    if @tagname == "div" and @end_comment_not_added
      id_or_class = self["id"]||self["class"]
      self.push @@start_of_page if id_or_class == "section h2"
      self.push HtmlElement.comment("end of #{id_or_class}") if id_or_class
      @end_comment_not_added = false
    end
  end
end
