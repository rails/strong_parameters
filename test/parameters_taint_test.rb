require 'test_helper'
require 'action_controller/parameters'

class ParametersTaintTest < ActiveSupport::TestCase
  setup do
    @params = ActionController::Parameters.new({ person: { 
      age: "32", name: { first: "David", last: "Heinemeier Hansson" }
    }})
  end

  test "empty values are OK" do
    @params[:foo] = {}
    assert @params.required(:foo)
  end

  test "taint is sticky on accessors" do
    assert !@params.slice(:person).permitted?
    assert !@params[:person][:name].permitted?

    @params.each { |key, value| assert(value.permitted?) if key == :person }

    assert !@params.fetch(:person).permitted?
    
    assert !@params.values_at(:person).first.permitted?
  end
  
  test "taint is sticky on mutators" do
    assert !@params.delete_if { |k| k == :person }.permitted?
    assert !@params.keep_if { |k,v| k == :person }.permitted?
  end
  
  test "taint is sticky beyond merges" do
    assert !@params.merge(a: "b").permitted?
  end
  
  test "modifying the parameters" do
    @params[:person][:hometown] = "Chicago"
    @params[:person][:family] = { brother: "Jonas" }

    assert_equal "Chicago", @params[:person][:hometown]
    assert_equal "Jonas", @params[:person][:family][:brother]
  end
end
