module ActiveModel
  class TaintedAttributes < StandardError
  end

  module MassAssignmentTaintProtection
    def sanitize_for_mass_assignment(new_attributes, options = {})
      if new_attributes.tainted?
        raise ActiveModel::TaintedAttributes
      else
        super
      end
    end
  end
end

ActiveModel.autoload :MassAssignmentTaintProtection
