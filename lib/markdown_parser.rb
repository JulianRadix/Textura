require 'redcarpet'

class MarkdownParser
  def initialize
    @renderer = Redcarpet::Render::HTML.new
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