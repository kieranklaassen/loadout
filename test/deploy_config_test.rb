require "test_helper"
require "erb"

class DeployConfigTest < ActiveSupport::TestCase
  DEPLOY_YML = Rails.root.join("config/deploy.yml")
  SECRETS = Rails.root.join(".kamal/secrets")
  DOCKERFILE = Rails.root.join("Dockerfile")

  # Every tenant-specific key the render requires (no defaults).
  REQUIRED_ENV = {
    "KAMAL_SERVICE" => "compound-stack",
    "KAMAL_IMAGE" => "ghcr.io/example/compound-stack",
    "KAMAL_WEB_HOST" => "203.0.113.10",
    "KAMAL_PROXY_HOST" => "compound-stack.example.test",
    "KAMAL_REGISTRY_USERNAME" => "example-user",
    "KAMAL_STORAGE_VOLUME" => "compound_stack_storage",
    "KAMAL_BUILDER_ARCH" => "amd64",
    "KAMAL_SSH_USER" => "deploy"
  }.freeze

  def render_deploy(env)
    original = ENV.to_hash
    (REQUIRED_ENV.keys | env.keys).each { |k| ENV.delete(k) }
    ENV.update(env)
    ERB.new(File.read(DEPLOY_YML)).result(binding)
  ensure
    ENV.replace(original)
  end

  test "renders to valid YAML reflecting the env under a full fixture env" do
    config = YAML.safe_load(render_deploy(REQUIRED_ENV))

    assert_equal REQUIRED_ENV["KAMAL_SERVICE"], config["service"]
    assert_equal REQUIRED_ENV["KAMAL_IMAGE"], config["image"]
    assert_includes config["servers"]["web"], REQUIRED_ENV["KAMAL_WEB_HOST"]
    assert_equal REQUIRED_ENV["KAMAL_PROXY_HOST"], config.dig("proxy", "host")
    assert_equal "/rails/public/vite", config["asset_path"]
    assert_equal "2.12.0", config["minimum_version"].to_s
  end

  test "fails loud (KeyError) when a required tenant key is missing" do
    assert_raises(KeyError) { render_deploy(REQUIRED_ENV.except("KAMAL_IMAGE")) }
  end

  test "no resolved secret or hardcoded IP is committed to deploy.yml" do
    deploy = File.read(DEPLOY_YML)
    assert_no_match(/\b\d{1,3}(\.\d{1,3}){3}\b/, deploy, "deploy.yml must not hardcode an IP address")
    assert_no_match(/password:\s*\S*(key|token|secret)\S*/i, deploy)
  end

  test ".kamal/secrets uses shell indirection only, never a raw value" do
    File.foreach(SECRETS) do |line|
      stripped = line.strip
      next if stripped.empty? || stripped.start_with?("#")

      _key, value = stripped.split("=", 2)
      assert value&.start_with?("$"),
        "#{line.inspect} must resolve via shell indirection ($(...) or $VAR), not a raw secret"
    end
  end

  test "Dockerfile exposes 80 and starts via thruster" do
    dockerfile = File.read(DOCKERFILE)
    assert_match(/^EXPOSE 80$/, dockerfile)
    assert_match(%r{CMD \["\./bin/thrust", "\./bin/rails", "server"\]}, dockerfile)
  end
end
