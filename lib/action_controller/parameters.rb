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

  module Filtering
    def atomic?(value)
      # We allow Integer for backwards compatibility. Parameters coming from web
      # requests are strings, but it is not uncommon that users set integer IDs
      # in controller tests, where the hash is passed as is to the controller.
      #
      # Note that we short-circuit the common case first.
      value.is_a?(String) || value.is_a?(Integer)
    end

    def array_of_atomics?(value)
      if value.is_a?(Array)
        value.all? {|_| atomic?(_)}
      end
    end

    def atomic_filter(params, key)
      if has_key?(key) && atomic?(self[key])
        params[key] = self[key]
      end

      keys.grep(/\A#{Regexp.escape(key.to_s)}\(\d+[if]?\)\z/).each do |key|
        if atomic?(self[key])
          params[key] = self[key]
        end
      end
    end

    def hash_filter(params, filter)
      filter = filter.with_indifferent_access

      # Slicing filters out non-declared keys.
      slice(*filter.keys).each do |key, value|
        return unless value

        if filter[key] == []
          # Declaration {:coment_ids => []}.
          array_of_atomics_filter(params, key)
        else
          # Declaration {:user => :name} or {:user => [:name, :age, {:adress => ...}]}.
          params[key] = each_element(value) do |element|
            if element.is_a?(Hash)
              element = self.class.new(element) unless element.respond_to?(:permit)
              element.permit(*Array.wrap(filter[key]))
            end
          end
        end
      end
    end

    def array_of_atomics_filter(params, key)
      if has_key?(key) && array_of_atomics?(self[key])
        params[key] = self[key]
      end
    end

    def each_element(value)
      if value.is_a?(Array)
        value.map { |el| yield el }.compact
        # fields_for on an array of records uses numeric hash keys.
      elsif value.is_a?(Hash) && value.keys.all? { |k| k =~ /\A-?\d+\z/ }
        hash = value.class.new
        value.each { |k,v| hash[k] = yield v }
        hash
      else
        yield value
      end
    end
  end

  class Parameters < ActiveSupport::HashWithIndifferentAccess
    include Filtering

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
        when Symbol, String
          atomic_filter(params, filter)
        when Hash then
          hash_filter(params, filter)
        end
      end

      params.permit!
    end

    def [](key)
      convert_hashes_to_parameters(key, super)
    end

    def fetch(key, *args)
      convert_hashes_to_parameters(key, super)
    rescue KeyError, IndexError
      raise ActionController::ParameterMissing.new(key)
    end

    def slice(*keys)
      self.class.new(super).tap do |new_instance|
        new_instance.instance_variable_set :@permitted, @permitted
      end
    end

    def dup
      self.class.new(self).tap do |duplicate|
        duplicate.default = default
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
