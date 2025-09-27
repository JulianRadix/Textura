require 'redcarpet'
require_relative 'markdown_renderer'

class MarkdownParser
  def initialize
    @renderer = HTMLWithRouge.new
    @markdown = Redcarpet::Markdown.new(@renderer,
      fenced_code_blocks: true,
      tables: true,
      autolink: true
    )
  end

  def to_html(text)
    @markdown.render(text)
  end
end