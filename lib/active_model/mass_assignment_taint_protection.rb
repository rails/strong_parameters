module ActiveModel
  class TaintedAttributes < StandardError
  end

  module MassAssignmentTaintProtection
    def sanitize_for_mass_assignment(new_attributes, options = {})
      unless new_attributes.permitted?
        raise ActiveModel::TaintedAttributes
      else
        super
      end
    end
  end
end

ActiveModel.autoload :MassAssignmentTaintProtection
