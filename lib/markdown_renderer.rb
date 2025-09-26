require 'rouge'
require 'redcarpet'
require 'rouge/plugins/redcarpet'

class HTMLWithRouge < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet
end