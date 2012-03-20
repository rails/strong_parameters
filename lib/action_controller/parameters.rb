require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'action_controller'

module ActionController
  class ParameterMissing < IndexError
  end

  class Parameters < ActiveSupport::HashWithIndifferentAccess
    attr_accessor :permitted
    alias :permitted? :permitted

    def initialize(attributes = nil, tainted = true)
      super(attributes)
      @permitted = false
    end

    def permit!
      @permitted = true
      self
    end

    def required(key)
      fetch(key) { raise ActionController::ParameterMissing }
    end

    def permit(*keys)
      slice(*keys).permit!
    end

    def [](key)
      convert_hashes_to_parameters(key, super)
    end

    def fetch(key)
      convert_hashes_to_parameters(key, super)
    end

    def slice(*keys)
      self.class.new(super)
    end

    private
      def convert_hashes_to_parameters(key, value)
        if value.is_a?(Parameters) || !value.is_a?(Hash)
          value
        else
          # Convert to Parameters on first access
          self[key] = self.class.new(value, tainted?)
        end
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

    def params=(val)
      @_tainted_params = Parameters.new(val)
    end
  end
end

ActionController::Base.send :include, ActionController::StrongParameters
