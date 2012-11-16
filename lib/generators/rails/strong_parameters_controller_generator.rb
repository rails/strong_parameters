require 'rails/version'
require 'rails/generators/rails/scaffold_controller/scaffold_controller_generator'

module Rails
  module Generators
    class StrongParametersControllerGenerator < ScaffoldControllerGenerator
      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"
      source_root File.expand_path("../templates", __FILE__)

      if ::Rails::VERSION::STRING < '3.1'
        def module_namespacing
          yield if block_given?
        end
      end
    end
  end
end
