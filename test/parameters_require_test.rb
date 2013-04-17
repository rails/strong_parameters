require 'test_helper'
require 'action_controller/parameters'

class ParametersRequireTest < ActiveSupport::TestCase
  test "required parameters must be present not merely not nil" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(:person => {}).require(:person)
    end
  end

  test "permit multiple required parameters" do
    params = ActionController::Parameters.new(:username => 'user', :password => '<3<3<3<3')
    assert_nothing_raised(ActionController::ParameterMissing) do
      params.require(:username, :password)
    end

    assert params.has_key?(:username)
    assert params.has_key?(:password)
  end

  test "multiple required parameters must be present not merely not nil" do
    params = ActionController::Parameters.new(:username => '', :password => nil)
    assert_raises(ActionController::ParameterMissing) do
      params.require(:username, :password)
    end
  end

  test "all parameters are returned after required with multiple parameters" do
    params = ActionController::Parameters.new(:username => 'user', :password => '<3<3<3<3', :version => 1)

    params.require(:username, :password)

    assert params.has_key?(:version)
  end
end
