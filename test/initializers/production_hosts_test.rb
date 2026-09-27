require "test_helper"
require "open3"
require "tmpdir"

# config/environments/production.rb decides which Host headers are served, which is
# only true in production, so this boots production in a subprocess (with a scratch
# database) and sends requests through the real middleware stack. The proxy's health
# check reaches the container by IP, so /up must pass host authorization while every
# other path with that Host is refused.
class ProductionHostsTest < ActiveSupport::TestCase
  PROBE = <<~RUBY
    probe = ->(path, host) { Rails.application.call(Rack::MockRequest.env_for(path, "HTTP_HOST" => host, "HTTPS" => "on")).first }
    puts "PROBE:" + {
      hosts: Rails.application.config.hosts.map(&:to_s),
      health_by_ip: probe.("/up", "172.18.0.5"),
      health_by_host: probe.("/up", "loadout.example.test"),
      other_path_by_ip: probe.("/anything", "172.18.0.5"),
      other_host: probe.("/", "evil.test"),
      public_host: probe.("/", "loadout.example.test")
    }.to_json
  RUBY

  test "production serves the public host, lets the proxy check /up by container IP, and refuses other hosts" do
    output, status = boot_production({ "PUBLIC_BASE_URL" => "https://loadout.example.test" }, PROBE)

    assert status.success?, output
    result = JSON.parse(output[/^PROBE:(.*)$/, 1])
    assert_equal [ "loadout.example.test" ], result["hosts"]
    assert_equal [ 200, 200 ], result.values_at("health_by_ip", "health_by_host")
    assert_equal [ 403, 403 ], result.values_at("other_path_by_ip", "other_host")
    assert_not_equal 403, result["public_host"]
  end

  test "production will not boot without PUBLIC_BASE_URL" do
    output, status = boot_production({}, "puts :booted")

    assert_not status.success?
    assert_match(/PUBLIC_BASE_URL is required in production/, output)
    assert_no_match(/^booted$/, output)
  end

  test "the asset build boots without it, on a dummy secret" do
    output, status = boot_production({ "SECRET_KEY_BASE_DUMMY" => "1", "SECRET_KEY_BASE" => nil }, "puts 'booted'")

    assert status.success?, output
    assert_match(/^booted$/, output)
  end

  private

  def boot_production(env, code)
    Dir.mktmpdir do |dir|
      base = { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => "k" * 64, "DATABASE_URL" => "sqlite3:#{dir}/production.sqlite3", "PUBLIC_BASE_URL" => nil, "SECRET_KEY_BASE_DUMMY" => nil }
      Open3.capture2e(base.merge(env), "bin/rails", "runner", code, chdir: Rails.root.to_s)
    end
  end
end
