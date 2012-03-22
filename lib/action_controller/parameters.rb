require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'action_controller'

module ActionController
  class ParameterMissing < IndexError
    attr_reader :param

    def initialize(param)
      @param = param
      super("key not found: #{param}")
    end
  end

  class Parameters < ActiveSupport::HashWithIndifferentAccess
    attr_accessor :permitted
    alias :permitted? :permitted

    def initialize(attributes = nil)
      super(attributes)
      @permitted = false
    end

    def permit!
      @permitted = true
      self
    end

    def required(key)
      self[key].presence || raise(ActionController::ParameterMissing.new(key))
    end

    def permit(*keys)
      slice(*keys).permit!
    end

    def [](key)
      convert_hashes_to_parameters(key, super)
    end

    def fetch(key)
      unless block_given? || key?(key)
        raise ActionController::ParameterMissing.new(key)
      end

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
          self[key] = self.class.new(value)
        end
      end
  end

  module StrongParameters
    extend ActiveSupport::Concern

    included do
      rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
        render text: "Required parameter missing: #{parameter_missing_exception.param}", status: :bad_request
      end
    end

    def params
      @_params ||= Parameters.new(request.parameters)
    end

    def params=(val)
      @_params = val.is_a?(Hash) ? Parameters.new(val) : val
    end
  end
end

ActionController::Base.send :include, ActionController::StrongParameters
