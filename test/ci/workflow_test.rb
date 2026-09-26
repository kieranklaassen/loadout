require "test_helper"

class CIWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = YAML.load_file(Rails.root.join(".github/workflows/ci.yml")).freeze
  SHA_PIN = %r{\A[\w.-]+/[\w.-]+(/[\w.-]+)*@[0-9a-f]{40}\z}

  test "the workflow parses and defines the four-job skeleton" do
    assert_equal %w[check_js lint scan_ruby test], WORKFLOW.fetch("jobs").keys.sort
  end

  test "every action is pinned to a 40-character commit SHA" do
    WORKFLOW.fetch("jobs").each do |job_name, job|
      job.fetch("steps").each do |step|
        uses = step["uses"]
        next unless uses

        assert_match SHA_PIN, uses, "#{job_name}: #{uses.inspect} must be pinned to a commit SHA"
      end
    end
  end
end
