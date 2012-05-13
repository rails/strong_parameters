require 'rails/generators/rails/scaffold_controller/scaffold_controller_generator'

module Rails
  module Generators
    class StrongParametersControllerGenerator < ScaffoldControllerGenerator
      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"
      source_root File.expand_path("../templates", __FILE__)
    end
  end
end
