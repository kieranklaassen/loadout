ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require "inertia_rails/minitest"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Rate limits live in owned in-process stores; never let counts leak between tests.
    setup do
      [ Oauth::RegistrationsController, Oauth::TokensController, Oauth::RevocationsController, McpController, HandlesController ].each do |controller|
        controller::RATE_LIMIT_STORE.clear
      end
    end

    # Add more helper methods to be used by all tests here...
  end
end
