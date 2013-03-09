require 'test_helper'
require 'action_controller/parameters'

class ParametersRequireTest < ActiveSupport::TestCase
  test "required parameters must be present" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(:name => {}).require(:person)
    end
  end

  test "required parameters can't be blank" do
    assert_raises(ActionController::EmptyParameter) do
      ActionController::Parameters.new(:person => {}).require(:person)
    end

    assert_raises(ActionController::EmptyParameter) do
      ActionController::Parameters.new(:person => '').require(:person)
    end

    assert_raises(ActionController::EmptyParameter) do
      ActionController::Parameters.new(:person => nil).require(:person)
    end
  end
end
