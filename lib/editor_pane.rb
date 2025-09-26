require 'gtk3'

class EditorPane
  attr_reader :widget, :buffer

  def initialize
    @text_view = Gtk::TextView.new
    @text_view.wrap_mode = :word
    @buffer = @text_view.buffer
    @buffer.text = "Type Markdown here..."

    @scrolled_window = Gtk::ScrolledWindow.new
    @scrolled_window.set_policy(:automatic, :automatic)
    @scrolled_window.add(@text_view)

    @widget = @scrolled_window
  end

  def on_text_change(&block)
    @buffer.signal_connect("changed") do
      block.call(@buffer.text)
    end
  end
end