# frozen_string_literal: true

namespace :users do
  desc "Create a user (the sole user writer — there is no open registration). " \
       "Usage: EMAIL=me@example.com PASSWORD=... bin/rails users:create"
  task create: :environment do
    email = ENV["EMAIL"].presence
    password = ENV["PASSWORD"].presence

    abort "EMAIL is required (EMAIL=you@example.com bin/rails users:create)" if email.nil?
    abort "PASSWORD is required (PASSWORD=... bin/rails users:create)" if password.nil?

    user = User.create!(email_address: email, password: password)
    puts "Created user #{user.email_address} (##{user.id})"
  rescue ActiveRecord::RecordInvalid => e
    abort "Could not create user: #{e.record.errors.full_messages.to_sentence}"
  end
end
