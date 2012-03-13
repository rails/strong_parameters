module ActiveModel
  class TaintedAttributes < StandardError
  end
  
  module MassAssignmentTaintProtection
    extend ActiveSupport::Concern
    
    included do
      alias_method_chain :sanitize_for_mass_assignment, :taint_checking
    end
    
    def sanitize_for_mass_assignment_with_taint_checking(new_attributes, options = {})
      if new_attributes.tainted?
        raise ActiveModel::TaintedAttributes
      else
        sanitize_for_mass_assignment_without_taint_checking(new_attributes, options)
      end
    end
  end
end

ActiveModel.autoload :MassAssignmentTaintProtection