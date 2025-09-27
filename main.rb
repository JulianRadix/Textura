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
# window.add(paned)

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

# Track Unsaved Changes
dirty = false

def update_title(window, file_manager, dirty)
  name = file_manager.current_path ? File.basename(file_manager.current_path) : "Untitled"
  window.set_title("Textura - #{'*' if dirty}#{name}")
end

# Live Markdown update
editor.on_text_change do |text|
  dirty = true
  update_title(window, file_manager, dirty)

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
accel_group = Gtk::AccelGroup.new
window.add_accel_group(accel_group)

window.signal_connect("key-press-event") do |_, event|
  ctrl = (event.state & Gdk::ModifierType::CONTROL_MASK) != 0
  next false unless ctrl  # Ignore if Ctrl not pressed

  case event.keyval
  when Gdk::Keyval::KEY_o
    open_file_dialog(window, file_manager, editor)
    dirty = false
    update_title(window, file_manager, dirty)
  when Gdk::Keyval::KEY_s
    save_file_dialog(window, file_manager, editor)
    dirty = false
    update_title(window, file_manager, dirty)
  end

  true  # Stop event propagation for Ctrl+O/Ctrl+S
end

# Menu Bar
menu_bar = Gtk::MenuBar.new

# File Menu
file_menu = Gtk::Menu.new
file_item = Gtk::MenuItem.new(label: "File")
file_item.set_submenu(file_menu)

# Open
open_item = Gtk::MenuItem.new(label: "Open")
open_item.signal_connect("activate") { open_file_dialog(window, file_manager, editor); dirty = false; update_title(window, file_manager, dirty) }
open_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_o, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
file_menu.append(open_item)

# Save
save_item = Gtk::MenuItem.new(label: "Save")
save_item.signal_connect("activate") { save_file_dialog(window, file_manager, editor); dirty = false; update_title(window, file_manager, dirty) }
save_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_s, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
file_menu.append(save_item)

# Save As
save_as_item = Gtk::MenuItem.new(label: "Save As")
save_as_item.signal_connect("activate") do
  temp_path = file_manager.current_path
  file_manager.instance_variable_set(:@current_path, nil)
  save_file_dialog(window, file_manager, editor)
  file_manager.instance_variable_set(:@current_path, temp_path)
  dirty = false
  update_title(window, file_manager, dirty)
end
file_menu.append(save_as_item)

# Exit
exit_item = Gtk::MenuItem.new(label: "Exit")
exit_item.signal_connect("activate") { window.destroy }
file_menu.append(exit_item)

menu_bar.append(file_item)

# Layout
vbox = Gtk::Box.new(:vertical, 0)
vbox.pack_start(menu_bar, expand: false, fill: false, padding: 0)
vbox.pack_start(paned, expand: true, fill: true, padding: 0)
window.add(vbox)

# Confirm Unsaved Changed On Exit
window.signal_connect("delete-event") do |_, _|
  if dirty
    dialog = Gtk::MessageDialog.new(
      parent: window,
      flags: :modal,
      type: :warning,
      buttons_type: :yes_no_cancel,
      message: "You have unsaved chaanges. Save before exiting?"
    )
    dialog.secondary_text = "Choose Yes to save, No to discard or Cancel to stay."

    response = dialog.run
    dialog.destroy

    case response
    when Gtk::ResponseType::YES
      save_file_dialog(window, file_manager, editor)
      Gtk.main_quit
    when Gtk::ResponseType::NO
      Gtk.main_quit
    else
      # Cancel: Do nothing
    end

    true # Stop default destroy signal until handled
  else
    false # allow window to close normally
  end
end

update_title(window, file_manager, dirty)
window.show_all
Gtk.main
