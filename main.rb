require 'gtk3'
require 'rouge'
require_relative 'lib/editor_pane'
require_relative 'lib/preview_pane'
require_relative 'lib/markdown_parser'

# Create main window
window = Gtk::Window.new
window.set_title("Textura")
window.set_default_size(800, 600)
window.signal_connect("destroy") { Gtk.main_quit }

# Split pane
paned = Gtk::Paned.new(:horizontal)
window.add(paned)

# Editor and preview panes
editor = EditorPane.new
preview = PreviewPane.new
parser = MarkdownParser.new

# Minimum sizes
editor.widget.set_size_request(200, 100)
preview.widget.set_size_request(200, 100)

# Add to paned
paned.add1(editor.widget)
paned.add2(preview.widget)

# Set initial divider position (center)
paned.position = 400
window.signal_connect("size-allocate") do |widget, allocation|
  paned.position = allocation.width / 2
end

# Rouge CSS
ROUGE_CSS = Rouge::Themes::ThankfulEyes.new.render

# Live Markdown update
editor.on_text_change do |text|
  html_body = parser.to_html(text)

  full_html = <<~HTML
    <html>
      <head>
        <style>
          #{ROUGE_CSS}
          body { font-family: sans-serif; padding: 10px; }
          pre { margin: 0; }
        </style>
      </head>
      <body>
        #{html_body}
      </body>
    </html>
  HTML

  preview.update(full_html)
end

window.show_all
Gtk.main
