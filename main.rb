require 'gtk3'
require 'rouge'
require_relative 'lib/editor_pane'
require_relative 'lib/preview_pane'
require_relative 'lib/file_manager'
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
editor      = EditorPane.new
preview     = PreviewPane.new
parser      = MarkdownParser.new
file_manager = FileManager.new

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

# File Open Dialog
def open_file_dialog(window, file_manager, editor)
  dialog = Gtk::FileChooserDialog.new(
    title: "Open Markdown File",
    parent: window,
    action: :open,
    buttons: [
      [Gtk::Stock::CANCEL, :cancel],
      [Gtk::Stock::OPEN, :accept]
    ]
  )
  dialog.add_filter(
    Gtk::FileFilter.new.tap do |f|
      f.name = "Markdown Files"
      f.add_pattern("*.md")
    end
  )

  if dialog.run == :accept
    content = file_manager.load_file(dialog.filename)
    editor.buffer.text = content
  end
  dialog.destroy
end

# Save File Dialog
def save_file_dialog(window, file_manager, editor)
  if file_manager.current_path
    file_manager.save_file(file_manager.current_path, editor.buffer.text)
  else
    dialog = Gtk::FileChooserDialog.new(
      title: "Save Markdown File",
      parent: window,
      action: :save,
      buttons: [
        [Gtk::Stock::CANCEL, :cancel],
        [Gtk::Stock::SAVE, :accept]
      ]
    )
    dialog.do_overwrite_confirmation = true

    if dialog.run == :accept
      file_manager.save_file(dialog.filename, editor.buffer.text)
    end
    dialog.destroy
  end
end

# Keyboard Shortcuts
window.add_accel_group(accel = Gtk::AccelGroup.new)

window.signal_connect("key-press-event") do |_, event|
  ctrl = (event.state & Gdk::ModifierType::CONTROL_MASK) != 0
  case event.keyval
  when Gdk::Keyval::KEY_o
    open_file_dialog(window, file_manager, editor) if ctrl
  when Gdk::Keyval::KEY_s
    save_file_dialog(window, file_manager, editor) if ctrl
  end
end

window.show_all
Gtk.main
