require 'gtk3'
require 'webkit2-gtk'

class PreviewPane
  attr_reader :widget

  def initialize
    # Create WebView for HTML content
    @webview = WebKit2Gtk::WebView.new

    # Wrap in a scrolled window
    @scrolled_window = Gtk::ScrolledWindow.new
    @scrolled_window.set_policy(:automatic, :automatic)
    @scrolled_window.add(@webview)

    @widget = @scrolled_window
  end

  def update(html_content)
    @webview.load_html(html_content, "file://")
  end
end