require 'test_helper'

class PeopleController < ActionController::Base
  def create
    params.required[:person]
    head :ok
  end
end

class ActionControllerTaintedParamsTest < ActionController::TestCase
  tests PeopleController
  
  test "missing required parameters will raise exception" do
    post :create, { user: { name: "Mjallo!" } }
    assert_response :bad_request
  end
  
  test "required parameters that are present will not raise" do
    post :create, { person: { name: "Mjallo!" } }
    assert_response :ok
  end
end
