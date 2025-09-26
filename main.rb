require 'gtk3'
require_relative 'lib/editor_pane'
require_relative 'lib/preview_pane'

window = Gtk::Window.new
window.set_title("Textura")
window.set_default_size(800, 600)
window.signal_connect("destroy") { Gtk.main_quit }

paned = Gtk::Paned.new(:horizontal)
window.add(paned)

editor = EditorPane.new
preview = PreviewPane.new

# Ensure minimum sizes
editor.widget.set_size_request(200, 100)
preview.widget.set_size_request(200, 100)

# Add to paned
paned.add1(editor.widget)
paned.add2(preview.widget)

# Set initial divider position
paned.position = 400

# Live update
editor.on_text_change do |text|
  preview.update(text)
end

window.show_all
Gtk.main
