require 'test_helper'
require 'action_controller/parameters'

class NestedParametersTest < ActiveSupport::TestCase
  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  #
  # -- Basic interface ---------------------------------------------------------
  #

  # --- nothing ----------------------------------------------------------------

  test 'if nothing is permitted, the hash becomes empty' do
    params = ActionController::Parameters.new(:id => '1234')
    permitted = params.permit
    permitted.permitted?
    permitted.empty?
  end

  # --- key --------------------------------------------------------------------

  test 'key: atomic values' do
    params = ActionController::Parameters.new(:id => '1234')
    permitted = params.permit(:id)
    assert_equal '1234', permitted[:id]

    %w(i f).each do |suffix|
      params = ActionController::Parameters.new("foo(000#{suffix})" => '5678')
      permitted = params.permit(:foo)
      assert_equal '5678', permitted["foo(000#{suffix})"]
    end
  end

  test 'key: unknown keys are filtered out' do
    params = ActionController::Parameters.new(:id => '1234', :injected => 'injected')
    permitted = params.permit(:id)
    assert_equal '1234', permitted[:id]
    assert_filtered_out permitted, :injected
  end

  test 'key: arrays are filtered out' do
    [[], [1], ['1']].each do |array|
      params = ActionController::Parameters.new(:id => array)
      permitted = params.permit(:id)
      assert_filtered_out permitted, :id

      %w(i f).each do |suffix|
        params = ActionController::Parameters.new("foo(000#{suffix})" => array)
        permitted = params.permit(:foo)
        assert_filtered_out permitted, "foo(000#{suffix})"
      end
    end
  end

  test 'key: hashes are filtered out' do
    [{}, {:foo => 1}, {:foo => 'bar'}].each do |hash|
      params = ActionController::Parameters.new(:id => hash)
      permitted = params.permit(:id)
      assert_filtered_out permitted, :id

      %w(i f).each do |suffix|
        params = ActionController::Parameters.new("foo(000#{suffix})" => hash)
        permitted = params.permit(:foo)
        assert_filtered_out permitted, "foo(000#{suffix})"
      end
    end
  end

  test 'key: non-atomic objects are filtered out' do
    params = ActionController::Parameters.new(:id => Object.new)
    permitted = params.permit(:id)
    assert_filtered_out permitted, :id

    %w(i f).each do |suffix|
      params = ActionController::Parameters.new("foo(000#{suffix})" => Object.new)
      permitted = params.permit(:foo)
      assert_filtered_out permitted, "foo(000#{suffix})"
    end
  end

  test 'key: it is not assigned if not present in params' do
    params = ActionController::Parameters.new(:name => 'Joe')
    permitted = params.permit(:id)
    assert !permitted.has_key?(:id)
  end

  # --- key to empty array -----------------------------------------------------

  test 'key to empty array: empty arrays pass' do
    params = ActionController::Parameters.new(:id => [])
    permitted = params.permit(:id => [])
    assert_equal [], permitted[:id]
  end

  test 'key to empty array: arrays of atomics pass' do
    [['foo'], [1], ['foo', 'bar'], [1, 2, 3]].each do |array|
      params = ActionController::Parameters.new(:id => array)
      permitted = params.permit(:id => [])
      assert_equal array, permitted[:id]
    end
  end

  test 'key to empty array: atomic values do not pass' do
    ['foo', 1].each do |atomic|
      params = ActionController::Parameters.new(:id => atomic)
      permitted = params.permit(:id => [])
      assert_filtered_out permitted, :id
    end
  end

  test 'key to empty array: arrays of non-atomic do not pass' do
    [[Object.new], [[]], [[1]], [{}], [{:id => '1'}]].each do |non_atomic|
      params = ActionController::Parameters.new(:id => non_atomic)
      permitted = params.permit(:id => [])
      assert_filtered_out permitted, :id
    end
  end

  #
  # --- Nesting ----------------------------------------------------------------
  #

  test "permitted nested parameters" do
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :authors => [{
          :name => "William Shakespeare",
          :born => "1564-04-26"
        }, {
          :name => "Christopher Marlowe"
        }, {
          :name => %w(malicious injected names)
        }],
        :details => {
          :pages => 200,
          :genre => "Tragedy"
        }
      },
      :magazine => "Mjallo!"
    })

    permitted = params.permit :book => [ :title, { :authors => [ :name ] }, { :details => :pages } ]

    assert permitted.permitted?
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]
    assert_equal 200, permitted[:book][:details][:pages]

    assert_filtered_out permitted[:book][:authors][2], :name

    assert_filtered_out permitted, :magazine
    assert_filtered_out permitted[:book][:details], :genre
    assert_filtered_out permitted[:book][:authors][0], :born
  end

  test "permitted nested parameters with a string or a symbol as a key" do
    params = ActionController::Parameters.new({
      :book => {
        'authors' => [
          { :name => "William Shakespeare", :born => "1564-04-26" },
          { :name => "Christopher Marlowe" }
        ]
      }
    })

    permitted = params.permit :book => [ { 'authors' => [ :name ] } ]

    assert_equal "William Shakespeare", permitted[:book]['authors'][0][:name]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book]['authors'][1][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]

    permitted = params.permit :book => [ { :authors => [ :name ] } ]

    assert_equal "William Shakespeare", permitted[:book]['authors'][0][:name]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book]['authors'][1][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]
  end

  test "nested arrays with strings" do
    params = ActionController::Parameters.new({
      :book => {
        :genres => ["Tragedy"]
      }
    })

    permitted = params.permit :book => {:genres => []}
    assert_equal ["Tragedy"], permitted[:book][:genres]
  end

  test "permit may specify symbols or strings" do
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :author => "William Shakespeare"
      },
      :magazine => "Shakespeare Today"
    })

    permitted = params.permit({ :book => ["title", :author] }, "magazine")
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:author]
    assert_equal "Shakespeare Today", permitted[:magazine]
  end

  test "nested array with strings that should be hashes" do
    params = ActionController::Parameters.new({
      :book => {
        :genres => ["Tragedy"]
      }
    })

    permitted = params.permit :book => { :genres => :type }
    assert permitted[:book][:genres].empty?
  end

  test "nested array with strings that should be hashes and additional values" do
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :genres => ["Tragedy"]
      }
    })

    permitted = params.permit :book => [ :title, { :genres => :type } ]
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert permitted[:book][:genres].empty?
  end

  test "nested string that should be a hash" do
    params = ActionController::Parameters.new({
      :book => {
        :genre => "Tragedy"
      }
    })

    permitted = params.permit :book => { :genre => :type }
    assert_nil permitted[:book][:genre]
  end

  test "fields_for_style_nested_params" do
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'0' => { :name => 'William Shakespeare', :age_of_death => '52' },
          :'1' => { :name => 'Unattributed Assistant' },
          :'2' => { :name => %w(injected names)}
        }
      }
    })
    permitted = params.permit :book => { :authors_attributes => [ :name ] }

    assert_not_nil permitted[:book][:authors_attributes]['0']
    assert_not_nil permitted[:book][:authors_attributes]['1']
    assert_empty permitted[:book][:authors_attributes]['2']
    assert_equal 'William Shakespeare', permitted[:book][:authors_attributes]['0'][:name]
    assert_equal 'Unattributed Assistant', permitted[:book][:authors_attributes]['1'][:name]

    assert_filtered_out permitted[:book][:authors_attributes]['0'], :age_of_death
  end

  test "fields_for_style_nested_params with negative numbers" do
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'-1' => { :name => 'William Shakespeare', :age_of_death => '52' },
          :'-2' => { :name => 'Unattributed Assistant' }
        }
      }
    })
    permitted = params.permit :book => { :authors_attributes => [:name] }

    assert_not_nil permitted[:book][:authors_attributes]['-1']
    assert_not_nil permitted[:book][:authors_attributes]['-2']
    assert_equal 'William Shakespeare', permitted[:book][:authors_attributes]['-1'][:name]
    assert_equal 'Unattributed Assistant', permitted[:book][:authors_attributes]['-2'][:name]

    assert_filtered_out permitted[:book][:authors_attributes]['-1'], :age_of_death
  end
end
