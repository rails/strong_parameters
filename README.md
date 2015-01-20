[![Travis CI](https://secure.travis-ci.org/rails/strong_parameters.png)](http://travis-ci.org/rails/strong_parameters) [![Gem Version](https://badge.fury.io/rb/strong_parameters.png)](http://badge.fury.io/rb/strong_parameters)
# Strong Parameters

With this plugin Action Controller parameters are forbidden to be used in Active Model mass assignments until they have been whitelisted. This means you'll have to make a conscious choice about which attributes to allow for mass updating and thus prevent accidentally exposing that which shouldn't be exposed.

In addition, parameters can be marked as required and flow through a predefined raise/rescue flow to end up as a 400 Bad Request with no effort.

``` ruby
class PeopleController < ActionController::Base
  # This will raise an ActiveModel::ForbiddenAttributes exception because it's using mass assignment
  # without an explicit permit step.
  def create
    Person.create(params[:person])
  end

  # This will pass with flying colors as long as there's a person key in the parameters, otherwise
  # it'll raise an ActionController::ParameterMissing exception, which will get caught by
  # ActionController::Base and turned into that 400 Bad Request reply.
  def update
    person = current_account.people.find(params[:id])
    person.update_attributes!(person_params)
    redirect_to person
  end

  private
    # Using a private method to encapsulate the permissible parameters is just a good pattern
    # since you'll be able to reuse the same permit list between create and update. Also, you
    # can specialize this method with per-user checking of permissible attributes.
    def person_params
      params.require(:person).permit(:name, :age)
    end
end
```

## Permitted Scalar Values

Given

``` ruby
params.permit(:id)
```

the key `:id` will pass the whitelisting if it appears in `params` and it has a permitted scalar value associated. Otherwise the key is going to be filtered out, so arrays, hashes, or any other objects cannot be injected.

The permitted scalar types are `String`, `Symbol`, `NilClass`, `Numeric`, `TrueClass`, `FalseClass`, `Date`, `Time`, `DateTime`, `StringIO`, `IO`, `ActionDispatch::Http::UploadedFile` and `Rack::Test::UploadedFile`.

To declare that the value in `params` must be an array of permitted scalar values map the key to an empty array:

``` ruby
params.permit(:id => [])
```

To whitelist an entire hash of parameters, the `permit!` method can be used

``` ruby
params.require(:log_entry).permit!
```

This will mark the `:log_entry` parameters hash and any subhash of it permitted.  Extreme care should be taken when using `permit!` as it will allow all current and future model attributes to be mass-assigned.

## Nested Parameters

You can also use permit on nested parameters, like:

``` ruby
params.permit(:name, {:emails => []}, :friends => [ :name, { :family => [ :name ], :hobbies => [] }])
```

This declaration whitelists the `name`, `emails` and `friends` attributes. It is expected that `emails` will be an array of permitted scalar values and that `friends` will be an array of resources with specific attributes : they should have a `name` attribute (any permitted scalar values allowed), a `hobbies` attribute as an array of permitted scalar values, and a `family` attribute which is restricted to having a `name` (any permitted scalar values allowed, too).

Thanks to Nick Kallen for the permit idea!

## Require Multiple Parameters

If you want to make sure that multiple keys are present in a params hash, you can call the method twice:

``` ruby
params.require(:token)
params.require(:post).permit(:title)
```

## Handling of Unpermitted Keys

By default parameter keys that are not explicitly permitted will be logged in the development and test environment. In other environments these parameters will simply be filtered out and ignored.

Additionally, this behaviour can be changed by changing the `config.action_controller.action_on_unpermitted_parameters` property in your environment files. If set to `:log` the unpermitted attributes will be logged, if set to `:raise` an exception will be raised.

## Use Outside of Controllers

While Strong Parameters will enforce permitted and required values in your application controllers, keep in mind
that you will need to sanitize untrusted data used for mass assignment when in use outside of controllers.

For example, if you retrieve JSON data from a third party API call and pass the unchecked parsed result on to
`Model.create`, undesired mass assignments could take place.  You can alleviate this risk by slicing the hash data,
or wrapping the data in a new instance of `ActionController::Parameters` and declaring permissions the same as
you would in a controller.  For example:

``` ruby
raw_parameters = { :email => "john@example.com", :name => "John", :admin => true }
parameters = ActionController::Parameters.new(raw_parameters)
user = User.create(parameters.permit(:name, :email))
```

## More Examples

Head over to the [Rails guide about Action Controller](http://guides.rubyonrails.org/action_controller_overview.html#more-examples).

## Installation

In Gemfile:

``` ruby
gem 'strong_parameters'
```

and then run `bundle`. To activate the strong parameters, you need to include this module in
every model you want protected.

``` ruby
class Post < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
end
```

Alternatively, you can protect all Active Record resources by default by creating an initializer and pasting the line:

``` ruby
ActiveRecord::Base.send(:include, ActiveModel::ForbiddenAttributesProtection)
```

If you want to now disable the default whitelisting that occurs in Rails 3.2, change the `config.active_record.whitelist_attributes` property in your `config/application.rb`:

``` ruby
config.active_record.whitelist_attributes = false
```

This will allow you to remove / not have to use `attr_accessible` and do mass assignment inside your code and tests.

## Migration Path to Rails 4

In order to have an idiomatic Rails 4 application, Rails 3 applications may
use this gem to introduce strong parameters in preparation for their upgrade.

The following is a way to do that gradually:

### 1 Depend on `strong_parameters`

Add this gem to the application `Gemfile`:

``` ruby
gem 'strong_parameters'
```

and run `bundle install`.

After this change, the `params` object in requests is of type
`ActionController::Parameters`. That is a subclass of
`ActiveSupport::HashWithIndifferentAccess` and therefore everything should
work as before. The test suite should be green, and the application can be
deployed.

### 2 Compute a Topological Sort of Active Record Models

We are going to work model by model, and the natural order to do that
systematically is topological. That is, if post has many comments, first you
do `Post`, and later you do `Comment`.

Reason is that order plays well with nested attributes. You can mass-assign
`ActionController::Parameters` to `Post`, and if that includes
`comments_attributes` and the `Comment` model is not yet done, it will work.
But if `Comment` is done first, then the mass-assigning to `Post` won't permit
its attributes and won't work.

This script prints a topological sort of the Active Record models to standard
output:

```ruby
require 'tsort'
require 'set'

class Graph < Hash
  include TSort

  alias tsort_each_node each_key

  def tsort_each_child(node, &block)
    fetch(node).each(&block)
  end
end

def children(model)
  Set.new.tap do |children|
    model.reflect_on_all_associations.each do |association|
      next unless [:has_many, :has_one].include?(association.macro)
      next if association.options[:through]

      children << association.klass
    end
  end
end

Dir.glob('app/models/**/*.rb') do |model|
  load model
end

graph = Graph.new
ActiveRecord::Base.descendants.each do |model|
  graph[model] = children(model) unless model.abstract_class?
end

graph.tsort.reverse_each do |klass|
  puts klass.name
end
```

Execute it with `rails runner`.

### 3 Protect Every Active Record Model, One at a Time

Once the dependency is in place and the topological listing computed, you can
work model by model. Do one model, deploy. Do another model, deploy. Etc.

For each model:

#### 3.1 Add Protection

Remove any `attr_accessible` or `attr_protected` declarations and include
`ActiveModel::ForbiddenAttributesProtection`:

``` ruby
class Post < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
end
```

#### 3.2 (Optional) Check the Suite is Red

If the application performs any mass-assignement into that model, the test
suite should not pass. Expect the test suite to raise
`ActiveModel::ForbiddenAttributes` in those spots.

If the test suite is green, either it lacks coverage (fix it), or there is no
mass-assignment going on (ready to deploy).

#### 3.3 Whitelisting

Go to every controller whose actions trigger mass-assignment on that model via
`params` and sanitize the input data using `require` and `permit`, as
explained above.

#### 3.4 Deploy

Once everything is whitelisted and the suite is green, this particular model
can be pushed.

Ready to work on the next model.

### 4 Add Protection Globally

Once all models are done, remove their inclusion of the protecting module:

``` ruby
class Post < ActiveRecord::Base
  # REMOVE THIS LINE IN EVERY PERSISTENT MODEL
  include ActiveModel::ForbiddenAttributesProtection
end
```

and add it globally in an initializer:

``` ruby
# config/initializers/strong_parameters.rb
ActiveRecord::Base.class_eval do
  include ActiveModel::ForbiddenAttributesProtection
end
```

### 5 Upgrade to Rails 4

To upgrade to Rails 4 just remove the previous initializer, everything else is
ready as far as strong parameters is concerned.

## Compatibility

This plugin is only fully compatible with Rails versions 3.0, 3.1 and 3.2 but not 4.0+, as it is part of Rails Core in 4.0.
An unofficial Rails 2 version is [strong_parameters_rails2](https://github.com/grosser/strong_parameters/tree/rails2).
