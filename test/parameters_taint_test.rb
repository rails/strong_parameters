require 'test_helper'
require 'action_controller/parameters'

class ParametersTaintTest < ActiveSupport::TestCase
  setup do
    @params = ActionController::Parameters.new({ person: { 
      age: "32", name: { first: "David", last: "Heinemeier Hansson" }
    }})
  end

  test "taint is sticky on accessors" do
    assert @params.slice(:person).tainted?
    assert @params[:person][:name].tainted?

    @params.each { |key, value| assert(value.tainted?) if key == :person }

    assert @params.fetch(:person).tainted?
    
    assert @params.values_at(:person).first.tainted?
  end
  
  test "taint is sticky on mutators" do
    assert @params.delete_if { |k| k == :person }.tainted?
    assert @params.keep_if { |k,v| k == :person }.tainted?
  end
  
  test "taint is sticky beyond merges" do
    assert @params.merge(a: "b").tainted?
  end
  
  test "modifying the parameters" do
    @params[:person][:hometown] = "Chicago"
    @params[:person][:family] = { brother: "Jonas" }

    assert_equal "Chicago", @params[:person][:hometown]
    assert_equal "Jonas", @params[:person][:family][:brother]
  end
end
