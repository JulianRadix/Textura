require "gtk3"

window = Gtk::Window.new("Textura")
window.set_size_request(400, 400)
window.set_border_width(10)

text_view = Gtk::TextView.new
text_view.buffer.text = "Start typing here..."
text_view.wrap_mode = :word

text_view.buffer.signal_connect("changed") do
  puts text_view.buffer.text
end

scrolled_window = Gtk::ScrolledWindow.new
scrolled_window.set_policy(:automatic, :automatic)
scrolled_window.add(text_view)

window.add(scrolled_window)
window.signal_connect("delete-event") { |_widget| Gtk.main_quit }
window.show_all()

Gtk.main