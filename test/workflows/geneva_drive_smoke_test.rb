# frozen_string_literal: true

require "test_helper"

class GenevaDriveSmokeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GenevaDrive::TestHelpers

  class TwoStepWorkflow < GenevaDrive::Workflow
    step :first do
      Thread.current[:geneva_drive_steps] << :first
    end

    step :second do
      Thread.current[:geneva_drive_steps] << :second
    end
  end

  class FailingWorkflow < GenevaDrive::Workflow
    step :unstable do
      Thread.current[:geneva_drive_attempts] += 1
      raise "temporary failure" if Thread.current[:geneva_drive_fail]
    end
  end

  class SolidQueueWorkflow < GenevaDrive::Workflow
    step :persisted_job do
      Thread.current[:geneva_drive_solid_queue_ran] = true
    end
  end

  setup do
    Thread.current[:geneva_drive_attempts] = 0
    Thread.current[:geneva_drive_fail] = false
    Thread.current[:geneva_drive_steps] = []
    Thread.current[:geneva_drive_solid_queue_ran] = false
    clear_enqueued_jobs
  end

  teardown do
    Thread.current[:geneva_drive_attempts] = nil
    Thread.current[:geneva_drive_fail] = nil
    Thread.current[:geneva_drive_steps] = nil
    Thread.current[:geneva_drive_solid_queue_ran] = nil
    clear_enqueued_jobs
  end

  test "loads the reviewed release with immediate test enqueue semantics" do
    assert_equal "0.6.0", GenevaDrive::VERSION
    assert_equal false, GenevaDrive.enqueue_after_commit
    assert_equal "default", GenevaDrive::PerformStepJob.queue_name
    assert_equal false, GenevaDrive::PerformStepJob.enqueue_after_transaction_commit
  end

  test "completes an ordered workflow and persists its history" do
    workflow = TwoStepWorkflow.create!(hero: users(:one))

    speedrun_workflow(workflow)

    assert_predicate workflow, :finished?
    assert_equal [ :first, :second ], Thread.current[:geneva_drive_steps]
    assert_equal %w[first second], workflow.step_executions.order(:created_at).pluck(:step_name)
    assert_equal %w[completed completed], workflow.step_executions.order(:created_at).pluck(:state)
  end

  test "duplicate delivery does not execute a completed step twice" do
    workflow = TwoStepWorkflow.create!(hero: users(:one))
    execution = workflow.step_executions.first

    GenevaDrive::PerformStepJob.perform_now(execution.id)
    GenevaDrive::PerformStepJob.perform_now(execution.id)

    assert_equal [ :first ], Thread.current[:geneva_drive_steps]
    assert_predicate execution.reload, :completed?
  end

  test "a failed step pauses and resume retries the same step" do
    Thread.current[:geneva_drive_fail] = true
    workflow = FailingWorkflow.create!(hero: users(:one))

    error = assert_raises(RuntimeError) { perform_next_step(workflow) }

    assert_equal "temporary failure", error.message
    assert_predicate workflow.reload, :paused?
    assert_equal "RuntimeError", workflow.step_executions.failed.first.error_class_name
    assert_equal "temporary failure", workflow.step_executions.failed.first.error_message

    Thread.current[:geneva_drive_fail] = false
    workflow.resume!
    perform_next_step(workflow)

    assert_predicate workflow.reload, :finished?
    assert_equal 2, Thread.current[:geneva_drive_attempts]
    assert_equal %w[failed completed], workflow.step_executions.order(:created_at).pluck(:state)
  end

  test "persists and performs a step through the separate Solid Queue database" do
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
    SolidQueue::Job.delete_all

    workflow = SolidQueueWorkflow.create!(hero: users(:one))
    execution = workflow.step_executions.first.reload
    job = SolidQueue::Job.find_by!(active_job_id: execution.job_id)

    assert_equal "GenevaDrive::PerformStepJob", job.class_name
    assert_equal "default", job.queue_name
    assert_not_equal ActiveRecord::Base.connection_db_config.database,
      SolidQueue::Record.connection_db_config.database

    GenevaDrive::PerformStepJob.perform_now(execution.id)

    assert_predicate workflow.reload, :finished?
    assert Thread.current[:geneva_drive_solid_queue_ran]
  ensure
    SolidQueue::Job.delete_all if SolidQueue::Job.table_exists?
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  test "housekeeping recovers a persisted step whose queue job was lost" do
    workflow = SolidQueueWorkflow.create!(hero: users(:one))
    lost_execution = workflow.step_executions.first
    clear_enqueued_jobs
    lost_execution.update!(scheduled_for: 16.minutes.ago, job_id: nil)

    result = GenevaDrive::HousekeepingJob.perform_now

    assert_equal 1, result.fetch(:stuck_scheduled_recovered)
    assert_equal "recovered", lost_execution.reload.outcome
    replacement = workflow.step_executions.scheduled.find_by!(step_name: "persisted_job")
    assert_not_equal lost_execution.id, replacement.id
    assert_enqueued_with(job: GenevaDrive::PerformStepJob, args: [ replacement.id ])

    GenevaDrive::PerformStepJob.perform_now(replacement.id)

    assert_predicate workflow.reload, :finished?
  end
end
