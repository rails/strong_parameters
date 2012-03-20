module ActiveModel
  class ForbiddenAttributes < StandardError
  end

  module MassAssignmentTaintProtection
    def sanitize_for_mass_assignment(new_attributes, options = {})
      if new_attributes.permitted?
        super
      else
        raise ActiveModel::ForbiddenAttributes
      end
    end
  end
end

ActiveModel.autoload :MassAssignmentTaintProtection
