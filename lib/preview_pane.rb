require 'gtk3'

class PreviewPane
  attr_reader :widget

  def initialize
    @label = Gtk::Label.new("Preview will appear here")
    @label.wrap = true

    @scrolled_window = Gtk::ScrolledWindow.new
    @scrolled_window.set_policy(:automatic, :automatic)
    @scrolled_window.add(@label)

    @widget = @scrolled_window
  end

  def update(content)
    @label.text = content
  end
end