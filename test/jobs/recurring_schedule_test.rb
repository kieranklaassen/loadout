require "test_helper"
require "erb"
require "ripper"

class RecurringScheduleTest < ActiveSupport::TestCase
  RECURRING = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).freeze
  QUEUE = YAML.load(
    ERB.new(File.read(Rails.root.join("config/queue.yml"))).result, aliases: true
  ).freeze

  test "every environment has a recurring key (config_from silently loads nothing otherwise)" do
    %w[production development test].each do |env|
      assert RECURRING.key?(env), "config/recurring.yml is missing a top-level #{env.inspect} key"
    end
  end

  test "each environment's clear-finished command is valid Ruby against a real method" do
    RECURRING.each_value do |tasks|
      command = tasks.dig("clear_solid_queue_finished_jobs", "command")
      assert command, "expected a clear_solid_queue_finished_jobs command"
      assert Ripper.sexp(command), "command is not valid Ruby: #{command}"
    end

    assert SolidQueue::Job.respond_to?(:clear_finished_in_batches),
      "the pruning method must exist on SolidQueue::Job"
  end

  test "each environment runs Geneva Drive housekeeping every 30 minutes" do
    RECURRING.each_value do |tasks|
      housekeeping = tasks.fetch("geneva_drive_housekeeping")

      assert_equal "GenevaDrive::HousekeepingJob", housekeeping.fetch("class")
      assert_equal "*/30 * * * *", housekeeping.fetch("schedule")
    end

    assert_operator GenevaDrive::HousekeepingJob, :<, ActiveJob::Base
  end

  test "JOB_CONCURRENCY defaults processes to 1 when unset" do
    worker = QUEUE.fetch("production").fetch("workers").first
    assert_equal 1, worker.fetch("processes")
    assert_equal 3, worker.fetch("threads")
    assert_in_delta 0.1, worker.fetch("polling_interval"), 0.0001
  end

  test "no whenever schedule.rb stub remains" do
    assert_not File.exist?(Rails.root.join("config/schedule.rb")),
      "Solid Queue's recurring.yml replaces whenever's schedule.rb"
  end
end
