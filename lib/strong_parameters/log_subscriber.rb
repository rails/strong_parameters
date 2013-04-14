module StrongParameters
  class LogSubscriber < ActiveSupport::LogSubscriber
    def unpermitted_parameters(event)
      unpermitted_keys = event.payload[:keys]
      debug("Unpermitted parameters: #{unpermitted_keys.join(", ")}")
    end

    def logger
      ActionController::Base.logger
    end
  end
end

StrongParameters::LogSubscriber.attach_to :action_controller
