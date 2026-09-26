require "test_helper"

class RiffrecShareTest < ActionDispatch::IntegrationTest
  def with_env(vars)
    original = ENV.to_hash
    ENV.update(vars)
    yield
  ensure
    ENV.replace(original)
  end

  test "unconfigured: capture is disabled and no riffrec config is shared" do
    with_env("RIFFREC_PUBLIC_KEY" => nil, "RIFFREC_ENDPOINT" => nil) do
      ENV.delete("RIFFREC_PUBLIC_KEY")
      ENV.delete("RIFFREC_ENDPOINT")
      get root_path

      assert_inertia_props({ feedback_capture_enabled: false })
      assert_nil inertia.props["riffrec"]
    end
  end

  test "configured: shares the gate and a browser-safe config with no secret field" do
    with_env("RIFFREC_PUBLIC_KEY" => "pk_placeholder", "RIFFREC_ENDPOINT" => "https://riffrec.example.test") do
      get root_path

      assert_inertia_props({ feedback_capture_enabled: true })

      config = inertia.props["riffrec"]
      assert_equal %w[endpoint public_key], config.keys.sort
      assert_equal "https://riffrec.example.test", config["endpoint"]
      config.each_key do |key|
        refute_match(/secret|password|api_key/i, key, "shared riffrec config must expose no secret-shaped field")
      end
    end
  end

  test "no real riffrec key or endpoint is committed to .env.example" do
    File.foreach(Rails.root.join(".env.example")) do |line|
      next unless line =~ /\ARIFFREC_(API_KEY|ENDPOINT)=/

      _key, value = line.strip.split("=", 2)
      assert value.to_s.empty?, "#{line.inspect} must ship a placeholder name with no value"
    end
  end
end
