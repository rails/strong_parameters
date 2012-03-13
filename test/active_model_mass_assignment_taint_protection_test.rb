require 'test_helper'

class Person
  include ActiveModel::MassAssignmentSecurity
  include ActiveModel::MassAssignmentTaintProtection
  
  public :sanitize_for_mass_assignment
end

class ActiveModelMassUpdateProtectionTest < ActiveSupport::TestCase
  test "tainted attributes cannot be used for mass updating" do
    assert_raises(ActiveModel::TaintedAttributes) do
      Person.new.sanitize_for_mass_assignment(ActionController::Parameters.new(a: "b"))
    end
  end

  test "untainted attributes can be used for mass updating" do
    assert_nothing_raised do
      assert_equal({ "a" => "b" },
        Person.new.sanitize_for_mass_assignment(ActionController::Parameters.new(a: "b").permit(:a)))
    end
  end
end
