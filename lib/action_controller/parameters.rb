require 'active_support/core_ext/hash/indifferent_access'

module ActionController
  class ParameterMissing < RuntimeError
  end

  class Parameters < ActiveSupport::HashWithIndifferentAccess
    def initialize(attributes = nil, tainted = true)
      super(attributes)
      taint if tainted
    end
  
    def required
      RequiredParameters.new(self, tainted?)
    end
    
    def [](key)
      if (value = super(key)).is_a?(Hash)
        self.class.new(value, tainted?)
      else
        value
      end
    end
    
    def permit(*keys)
      slice(*keys).untaint
    end
  end

  class RequiredParameters < Parameters
    def [](key)
      super(key).presence || raise(ActionController::ParameterMissing)
    end
  end
  
  module StrongParameters
    def params
      @_tainted_params ||= Parameters.new(super)
    end
  end
end

ActionController::Base.send :include, ActionController::StrongParameters
ActionController::Base.rescue_from(ActionController::ParameterMissing) { head :bad_request }