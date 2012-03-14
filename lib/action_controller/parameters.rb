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
    
    def permit(*keys)
      slice(*keys).untaint
    end
    

    def [](key)
      return_as_tainted_parameters_if_hash(super)
    end
    
    def fetch(key)
      return_as_tainted_parameters_if_hash(super)
    end
    

    private
      def return_as_tainted_parameters_if_hash(value)
        value.is_a?(Hash) ? self.class.new(value, tainted?) : value
      end
  end

  class RequiredParameters < Parameters
    def [](key)
      super(key).presence || raise(ActionController::ParameterMissing)
    end
  end
  
  module StrongParameters
    extend ActiveSupport::Concern
    
    included do
      rescue_from(ActionController::ParameterMissing) { head :bad_request }
    end
    
    def params
      @_tainted_params ||= Parameters.new(super)
    end
  end
end

ActionController::Base.send :include, ActionController::StrongParameters