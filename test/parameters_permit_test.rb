require 'test_helper'
require 'action_controller/parameters'
require 'action_dispatch/http/upload'

class NestedParametersTest < ActiveSupport::TestCase
  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  #
  # --- Basic interface --------------------------------------------------------
  #

  # --- nothing ----------------------------------------------------------------

  test 'if nothing is permitted, the hash becomes empty' do
    params = ActionController::Parameters.new(:id => '1234')
    permitted = params.permit
    assert permitted.permitted?
    assert permitted.empty?
  end

  # --- key --------------------------------------------------------------------

  test 'key: permitted scalar values' do
    values  = ['a', :a, nil]
    values += [0, 1.0, 2**128, BigDecimal.new('1')]
    values += [true, false]
    values += [Date.today, Time.now, DateTime.now]
    values += [StringIO.new, STDOUT, ActionDispatch::Http::UploadedFile.new(:tempfile => __FILE__), Rack::Test::UploadedFile.new(__FILE__)]

    values.each do |value|
      params = ActionController::Parameters.new(:id => value)
      permitted = params.permit(:id)
      assert_equal value, permitted[:id]

      %w(i f).each do |suffix|
        params = ActionController::Parameters.new("foo(000#{suffix})" => value)
        permitted = params.permit(:foo)
        assert_equal value, permitted["foo(000#{suffix})"]
      end
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

  test 'key: non-permitted scalar values are filtered out' do
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

  test 'do not break params filtering on nil values' do
    params = ActionController::Parameters.new(:a => 1, :b => [1, 2, 3], :c => nil)

    permitted = params.permit(:a, :c => [], :b => [])
    assert_equal 1, permitted[:a]
    assert_equal [1, 2, 3], permitted[:b]
    assert_equal nil, permitted[:c]
  end

  # --- key to empty array -----------------------------------------------------

  test 'key to empty array: empty arrays pass' do
    params = ActionController::Parameters.new(:id => [])
    permitted = params.permit(:id => [])
    assert_equal [], permitted[:id]
  end

  test 'key to empty array: arrays of permitted scalars pass' do
    [['foo'], [1], ['foo', 'bar'], [1, 2, 3]].each do |array|
      params = ActionController::Parameters.new(:id => array)
      permitted = params.permit(:id => [])
      assert_equal array, permitted[:id]
    end
  end

  test 'key to empty array: permitted scalar values do not pass' do
    ['foo', 1].each do |permitted_scalar|
      params = ActionController::Parameters.new(:id => permitted_scalar)
      permitted = params.permit(:id => [])
      assert_filtered_out permitted, :id
    end
  end

  test 'key to empty array: arrays of non-permitted scalar do not pass' do
    [[Object.new], [[]], [[1]], [{}], [{:id => '1'}]].each do |non_permitted_scalar|
      params = ActionController::Parameters.new(:id => non_permitted_scalar)
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
    assert permitted[:book][:authors_attributes]['2'].empty?
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

  test "fields_for_style_nested_params with nested arrays" do
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'0' => ['William Shakespeare', '52'],
          :'1' => ['Unattributed Assistant']
        }
      }
    })
    permitted = params.permit :book => { :authors_attributes => { :'0' => [], :'1' => [] } }

    assert_not_nil permitted[:book][:authors_attributes]['0']
    assert_not_nil permitted[:book][:authors_attributes]['1']
    assert_nil permitted[:book][:authors_attributes]['2']
    assert_equal 'William Shakespeare', permitted[:book][:authors_attributes]['0'][0]
    assert_equal 'Unattributed Assistant', permitted[:book][:authors_attributes]['1'][0]
  end

  test "nested number as key" do
    params = ActionController::Parameters.new({
      :product => {
        :properties => {
          '0' => "prop0",
          '1' => "prop1"
        }
      }
    })
    params = params.require(:product).permit(:properties => ["0"])
    assert_not_nil        params[:properties]["0"]
    assert_nil            params[:properties]["1"]
    assert_equal "prop0", params[:properties]["0"]
  end

  test "fetch with a default value of a hash does not mutate the object" do
    params = ActionController::Parameters.new({})
    params.fetch :foo, {}
    assert_equal nil, params[:foo]
  end

  test 'hashes in array values get wrapped' do
    params = ActionController::Parameters.new(foo: [{}, {}])
    params[:foo].each do |hash|
      assert !hash.permitted?
    end
  end
end
