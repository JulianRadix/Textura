require 'gtk3'

class EditorPane
  attr_reader :widget, :buffer, :undo_stack, :redo_stack

  def initialize
    @text_view = Gtk::TextView.new
    @text_view.wrap_mode = :word
    @buffer = @text_view.buffer
    @buffer.text = "Type Markdown here..."

    # Undo/Redo stacks
    @undo_stack = []
    @redo_stack = []
    @ignore_change = false

    # Track changes for undo
    @buffer.signal_connect("changed") do
      next if @ignore_change
      @undo_stack.push(@buffer.text)
      @redo_stack.clear
    end

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

  # Undo last change
  def undo
    return if @undo_stack.empty?
    @ignore_change = true
    last_text = @undo_stack.pop
    @redo_stack.push(@buffer.text)
    @buffer.text = last_text
    @ignore_change = false
  end

  # Redo last undone change
  def redo
    return if @redo_stack.empty?
    @ignore_change = true
    next_text = @redo_stack.pop
    @undo_stack.push(@buffer.text)
    @buffer.text = next_text
    @ignore_change = false
  end

  # Clipboard operations
  def cut_clipboard(clipboard)
    @buffer.cut_clipboard(clipboard, true)
  end

  def copy_clipboard(clipboard)
    @buffer.copy_clipboard(clipboard)
  end

  def paste_clipboard(clipboard)
    @buffer.paste_clipboard(clipboard, nil, true)
  end
end
