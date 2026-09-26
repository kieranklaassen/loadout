require "test_helper"
require "rake"

class UsersRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("users:create")
    Rake::Task["users:create"].reenable
  end

  test "users:create creates a persisted, authenticatable user" do
    ENV["EMAIL"] = "rake-created@example.com"
    ENV["PASSWORD"] = "Secret-Passw0rd"

    assert_difference -> { User.count }, 1 do
      Rake::Task["users:create"].invoke
    end

    assert User.authenticate_by(email_address: "rake-created@example.com", password: "Secret-Passw0rd"),
      "the user created by the rake task should authenticate"
  ensure
    ENV.delete("EMAIL")
    ENV.delete("PASSWORD")
  end

  test "no open registration route exists" do
    helpers = Rails.application.routes.url_helpers

    assert_not helpers.respond_to?(:users_path), "there must be no users create/registration route"
    assert_not helpers.respond_to?(:new_user_registration_path)
  end
end
