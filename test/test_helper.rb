# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require 'test/unit'
require 'strong_parameters'
require 'mocha'

module ActionController
  SharedTestRoutes = ActionDispatch::Routing::RouteSet.new
  SharedTestRoutes.draw do
    match ':controller(/:action)'
  end

  class Base
    include ActionController::Testing
    include SharedTestRoutes.url_helpers
  end

  class ActionController::TestCase
    setup do
      @routes = SharedTestRoutes
    end
  end
end


# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
