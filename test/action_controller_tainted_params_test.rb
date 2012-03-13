require 'test_helper'

class PeopleController < ActionController::Base
  def create
    render text: params[:person].tainted? ? "tainted" : "untainted"
  end
  
  def create_with_permit
    render text: params[:person].permit(:name).tainted? ? "tainted" : "untainted"
  end
end

class ActionControllerTaintedParamsTest < ActionController::TestCase
  tests PeopleController
  
  test "parameters are tainted" do
    post :create, { person: { name: "Mjallo!" } }
    assert_equal "tainted", response.body
  end
  
  test "parameters can be permitted and are then not tainted" do
    post :create_with_permit, { person: { name: "Mjallo!" } }
    assert_equal "untainted", response.body
  end
end
