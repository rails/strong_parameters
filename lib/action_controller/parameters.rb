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
      each_pair do |key, value|
        convert_hashes_to_parameters(key, value)
        self[key].permit! if self[key].respond_to? :permit!
      end

      @permitted = true
      self
    end

    def require(key)
      self[key].presence || raise(ActionController::ParameterMissing.new(key))
    end

    alias :required :require

    def permit(*filters)
      params = self.class.new

      filters.each do |filter|
        case filter
        when Symbol, String then
          params[filter] = self[filter] if has_key?(filter)
          keys.grep(/\A#{Regexp.escape(filter)}\(\d+[if]?\)\z/).each { |key| params[key] = self[key] }
        when Hash then
          self.slice(*filter.keys).each do |key, value|
            return unless value

            key = key.to_sym

            params[key] = each_element(value) do |value|
              # filters are a Hash, so we expect value to be a Hash too
              next if filter.is_a?(Hash) && !value.is_a?(Hash)

              value = self.class.new(value) if !value.respond_to?(:permit)

              value.permit(*Array.wrap(filter[key]))
            end
          end
        end
      end

      params.permit!
    end

    def [](key)
      convert_hashes_to_parameters(key, super)
    end

    def fetch(key, *args)
      convert_hashes_to_parameters(key, super)
    rescue KeyError
      raise ActionController::ParameterMissing.new(key)
    end

    def slice(*keys)
      self.class.new(super)
    end

    def dup
      super.tap do |duplicate|
        duplicate.instance_variable_set :@permitted, @permitted
      end
    end

    protected
      def convert_value(value)
        if value.class == Hash
          self.class.new_from_hash_copying_default(value)
        elsif value.is_a?(Array)
          value.dup.replace(value.map { |e| convert_value(e) })
        else
          value
        end
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

      def each_element(object)
        if object.is_a?(Array)
          object.map { |el| yield el }.compact
        # fields_for on an array of records uses numeric hash keys
        elsif object.is_a?(Hash) && object.keys.all? { |k| k =~ /\A-?\d+\z/ }
          hash = object.class.new
          object.each { |k,v| hash[k] = yield v }
          hash
        else
          yield object
        end
      end
  end

  module StrongParameters
    extend ActiveSupport::Concern

    included do
      rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
        render :text => "Required parameter missing: #{parameter_missing_exception.param}", :status => :bad_request
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
