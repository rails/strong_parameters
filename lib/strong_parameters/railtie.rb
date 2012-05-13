require 'rails/railtie'

module StrongParameters
  class Railtie < ::Rails::Railtie
    if config.respond_to?(:app_generators)
      config.app_generators.scaffold_controller = :strong_parameters_controller
    else
      config.generators.scaffold_controller = :strong_parameters_controller
    end
  end
end
