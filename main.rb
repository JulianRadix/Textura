require 'gtk3'
require 'rouge'
require_relative 'lib/editor_pane'
require_relative 'lib/preview_pane'
require_relative 'lib/file_manager'
require_relative 'lib/markdown_parser'

# --- Window setup ---
window = Gtk::Window.new
window.set_default_size(800, 600)
window.signal_connect("destroy") { Gtk.main_quit }

# --- Editor / Preview / Parser / FileManager ---
editor       = EditorPane.new
preview      = PreviewPane.new
parser       = MarkdownParser.new
file_manager = FileManager.new

# Clipboard
clipboard = Gtk::Clipboard.get(Gdk::Atom.intern("CLIPBOARD", false))

# Minimum sizes
editor.widget.set_size_request(200, 100)
preview.widget.set_size_request(200, 100)

# Split pane
paned = Gtk::Paned.new(:horizontal)
paned.add1(editor.widget)
paned.add2(preview.widget)
paned.position = window.default_width / 2
window.signal_connect("size-allocate") { |_, alloc| paned.position = alloc.width / 2 }

# --- Rouge CSS ---
ROUGE_CSS = Rouge::Themes::ThankfulEyes.new.render

# --- Track Unsaved Changes ---
dirty = false

def update_title(window, file_manager, dirty)
  name = file_manager.current_path ? File.basename(file_manager.current_path) : "Untitled"
  window.set_title("Textura - #{'*' if dirty}#{name}")
end

# --- Status Bar ---
statusbar = Gtk::Statusbar.new
status_context = statusbar.get_context_id("main")

def update_statusbar(statusbar, context, file_manager, dirty)
  name = file_manager.current_path ? File.basename(file_manager.current_path) : "Untitled"
  state = dirty ? "Unsaved ✎" : "Saved ✔"
  statusbar.pop(context)
  statusbar.push(context, "#{state} | #{name}")
end

# --- Live Markdown update ---
editor.on_text_change do |text|
  dirty = true
  update_title(window, file_manager, dirty)
  update_statusbar(statusbar, status_context, file_manager, dirty)

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

# --- File Dialogs ---
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
  dialog.add_filter(Gtk::FileFilter.new.tap { |f| f.name = "Markdown Files"; f.add_pattern("*.md") })

  if dialog.run == :accept
    content = file_manager.load_file(dialog.filename)
    editor.buffer.text = content
  end
  dialog.destroy
end

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

def save_as_dialog(window, file_manager, editor)
  dialog = Gtk::FileChooserDialog.new(
    title: "Save Markdown As...",
    parent: window,
    action: :save,
    buttons: [
      [Gtk::Stock::CANCEL, :cancel],
      [Gtk::Stock::SAVE, :accept]
    ]
  )
  dialog.do_overwrite_confirmation = true

  # Optional: filter for Markdown files
  dialog.add_filter(Gtk::FileFilter.new.tap do |f|
    f.name = "Markdown Files"
    f.add_pattern("*.md")
  end)

  if dialog.run == :accept
    file_manager.save_file(dialog.filename, editor.buffer.text)
    editor.buffer.text # ensure dirty is updated elsewhere
  end

  dialog.destroy
end

# --- Keyboard shortcuts ---
accel_group = Gtk::AccelGroup.new
window.add_accel_group(accel_group)

window.signal_connect("key-press-event") do |_, event|
  handled = false
  state = event.state

  ctrl  = (state & Gdk::ModifierType::CONTROL_MASK) != 0
  shift = (state & Gdk::ModifierType::SHIFT_MASK) != 0

  case event.keyval
  when Gdk::Keyval::KEY_s, Gdk::Keyval::KEY_S
    if ctrl && shift
      # Ctrl+Shift+S → Save As
      save_as_dialog(window, file_manager, editor)
      dirty = false
      update_title(window, file_manager, dirty)
      update_statusbar(statusbar, status_context, file_manager, dirty)
      handled = true
    elsif ctrl
      # Ctrl+S → Save
      save_file_dialog(window, file_manager, editor)
      dirty = false
      update_title(window, file_manager, dirty)
      update_statusbar(statusbar, status_context, file_manager, dirty)
      handled = true
    end
  when Gdk::Keyval::KEY_a
    editor.buffer.select_range(editor.buffer.start_iter, editor.buffer.end_iter) if ctrl
    handled = true if ctrl
  when Gdk::Keyval::KEY_c
    editor.buffer.copy_clipboard(clipboard) if ctrl
    handled = true if ctrl
  when Gdk::Keyval::KEY_v
    editor.buffer.paste_clipboard(clipboard, nil, true) if ctrl
    handled = true if ctrl
  when Gdk::Keyval::KEY_z
    editor.undo if ctrl
    handled = true if ctrl
  when Gdk::Keyval::KEY_y
    editor.redo if ctrl
    handled = true if ctrl
  end

  handled
end

# --- Menu Bar ---
menu_bar = Gtk::MenuBar.new

# File Menu
file_menu = Gtk::Menu.new
file_item = Gtk::MenuItem.new(label: "File")
file_item.set_submenu(file_menu)

# Open
open_item = Gtk::MenuItem.new(label: "Open")
open_item.signal_connect("activate") do
  open_file_dialog(window, file_manager, editor)
  dirty = false
  update_title(window, file_manager, dirty)
  update_statusbar(statusbar, status_context, file_manager, dirty)
end
open_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_o, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
file_menu.append(open_item)

# Save
save_item = Gtk::MenuItem.new(label: "Save")
save_item.signal_connect("activate") do
  save_file_dialog(window, file_manager, editor)
  dirty = false
  update_title(window, file_manager, dirty)
  update_statusbar(statusbar, status_context, file_manager, dirty)
end
save_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_s, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
file_menu.append(save_item)

# Save As
save_as_item = Gtk::MenuItem.new(label: "Save As")
save_as_item.signal_connect("activate") do
  save_as_dialog(window, file_manager, editor)
  dirty = false
  update_title(window, file_manager, dirty)
  update_statusbar(statusbar, status_context, file_manager, dirty)
end
file_menu.append(save_as_item)

# Exit
exit_item = Gtk::MenuItem.new(label: "Exit")
exit_item.signal_connect("activate") { window.destroy }
file_menu.append(exit_item)

menu_bar.append(file_item)

# Edit menu
edit_menu = Gtk::Menu.new
edit_item = Gtk::MenuItem.new(label: "Edit")
edit_item.set_submenu(edit_menu)

# # Undo
# undo_item = Gtk::MenuItem.new(label: "Undo")
# undo_item.signal_connect("activate") { editor.undo }
# undo_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_z, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
# edit_menu.append(undo_item)

# # Redo
# redo_item = Gtk::MenuItem.new(label: "Redo")
# redo_item.signal_connect("activate") { editor.redo }
# redo_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_y, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
# edit_menu.append(redo_item)

# Cut
cut_item = Gtk::MenuItem.new(label: "Cut")
cut_item.signal_connect("activate") { editor.buffer.cut_clipboard(clipboard, true) }
cut_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_x, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
edit_menu.append(cut_item)

# Copy
copy_item = Gtk::MenuItem.new(label: "Copy")
copy_item.signal_connect("activate") { editor.buffer.copy_clipboard(clipboard) }
copy_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_c, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
edit_menu.append(copy_item)

# Paste
paste_item = Gtk::MenuItem.new(label: "Paste")
paste_item.signal_connect("activate") { editor.buffer.paste_clipboard(clipboard, nil, true) }
paste_item.add_accelerator("activate", accel_group, Gdk::Keyval::KEY_v, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE)
edit_menu.append(paste_item)

menu_bar.append(edit_item)

# --- Layout ---
vbox = Gtk::Box.new(:vertical, 0)
vbox.pack_start(menu_bar, expand: false, fill: false, padding: 0)
vbox.pack_start(paned, expand: true, fill: true, padding: 0)
vbox.pack_start(statusbar, expand: false, fill: true, padding: 0)
window.add(vbox)

# --- Confirm Unsaved Changes on Exit ---
window.signal_connect("delete-event") do |_, _|
  if dirty
    dialog = Gtk::MessageDialog.new(
      parent: window,
      flags: :modal,
      type: Gtk::MessageType::WARNING,
      buttons_type: Gtk::ButtonsType::YES_NO_CANCEL,
      message: "You have unsaved changes. Save before exiting?"
    )
    dialog.secondary_text = "Choose Yes to save, No to discard, or Cancel to stay."
    response = dialog.run
    dialog.destroy

    case response
    when Gtk::ResponseType::YES
      save_file_dialog(window, file_manager, editor)
      Gtk.main_quit
    when Gtk::ResponseType::NO
      Gtk.main_quit
    else
      true # Cancel: stop window from closing
    end

    true
  else
    false
  end
end

# --- Initial Updates & Show ---
update_title(window, file_manager, dirty)
update_statusbar(statusbar, status_context, file_manager, dirty)
window.show_all
Gtk.main