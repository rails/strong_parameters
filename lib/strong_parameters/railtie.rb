require 'rails/railtie'

module StrongParameters
  class Railtie < ::Rails::Railtie
    if config.respond_to?(:app_generators)
      config.app_generators.scaffold_controller = :strong_parameters_controller
    else
      config.generators.scaffold_controller = :strong_parameters_controller
    end

    initializer "strong_parameters.config", :before => "active_controller.set_configs" do |app| 
      ActionController::Parameters.action_on_unpermitted_parameters = options.delete(:action_on_unpermitted_parameters) do
        (Rails.env.test? || Rails.env.development?) ? :log : false
      end
    end
  end
end
