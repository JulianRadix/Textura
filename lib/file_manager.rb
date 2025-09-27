class FileManager
  attr_reader :current_path

  def intialize
    @current_path = nil
  end

  def load_file(path)
    @current_path = path
    File.read(path)
  end

  def save_file(path, content)
    # Ensure .md extension
    path += ".md" unless File.extname(path).downcase == ".md"
    File.write(path, content)
    @current_path = path
  end
end