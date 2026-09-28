require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  test "suggested items get a monogram, a stable hue and a slug with a random suffix" do
    item = AiModel.create!(name: "hedra character 3", status: "pending", created_by: users(:one))

    assert_equal "Hc", item.monogram
    assert_equal AiModel.hue_for("hedra character 3"), item.hue
    assert_match(/\Ahedra-character-3-[a-z0-9]{4}\z/, item.slug)
  end

  test "a suggested slug has the same shape whether or not another member has that name pending" do
    theirs = AiModel.create!(name: "Mystery 3", status: "pending", created_by: users(:two))
    ours = AiModel.create!(name: "Mystery 3", status: "pending", created_by: users(:one))

    [ theirs, ours ].each { |item| assert_match(/\Amystery-3-[a-z0-9]{4}\z/, item.slug) }
  end

  test "an approved suggestion takes the plain slug when it is free, else keeps its own" do
    first = AiModel.create!(name: "Mystery 3", status: "pending", created_by: users(:one))
    second = AiModel.create!(name: "Mystery 3", status: "pending", created_by: users(:two))
    kept = second.slug

    first.update!(status: "approved")
    second.update!(status: "approved")

    assert_equal [ "mystery-3", kept ], [ first.reload.slug, second.reload.slug ]
  end

  test "the Vibe Check link must be https on an allowed host with no credentials or port" do
    valid = %w[
      https://every.to/vibe-checks/opus https://checks.every.to/opus https://EVERY.TO/x https://checks.every.to https://checks.every.to:443/x
      https://every.to/path?q=1#frag
    ]
    invalid = [
      "http://every.to/x", "https://every.to:8443/x", "https://user@every.to/x", "https://user:pass@every.to/x", "https://every.to@evil.com/x",
      "https://evil-every.to/x", "https://every.to.evil.com/x", "https://evil.com/every.to", "https://sub.every.to/x", "https://every.to./x",
      "https://every.to\\@evil.com/x", "https:\\\\every.to/x", "//every.to/x", "javascript:alert(1)", "every.to/x", "https://every.to/a b", "https:///x"
    ]

    valid.each { |url| assert ai_models(:gpt_6).tap { |model| model.vibe_check_url = url }.valid?, "#{url} should be allowed" }
    invalid.each do |url|
      model = ai_models(:gpt_6).tap { |item| item.vibe_check_url = url }
      assert_not model.valid?, "#{url} should be rejected"
      assert_match(/every\.to or checks\.every\.to/, model.errors[:vibe_check_url].first)
    end
  end

  test "a blank Vibe Check link is fine and is stored as none" do
    model = ai_models(:gpt_6)
    model.update!(vibe_check_url: "  ")

    assert_nil model.vibe_check_url
  end

  test "VIBE_CHECK_HOSTS replaces the allowed hosts, and only exact hosts match" do
    ENV["VIBE_CHECK_HOSTS"] = "vibes.example.test, Checks.Example.Test"
    model = ai_models(:gpt_6)

    assert model.tap { |item| item.vibe_check_url = "https://vibes.example.test/x" }.valid?
    assert model.tap { |item| item.vibe_check_url = "https://checks.example.test/x" }.valid?
    assert_not model.tap { |item| item.vibe_check_url = "https://every.to/x" }.valid?
    assert_not model.tap { |item| item.vibe_check_url = "https://evil.vibes.example.test/x" }.valid?
  ensure
    ENV.delete("VIBE_CHECK_HOSTS")
  end

  test "a launched model has both a release date and a valid link, and is approved" do
    assert_equal [ ai_models(:opus_5_5) ], AiModel.launched.to_a, "opus_5 has a date only, gpt_6 has neither"

    ai_models(:opus_5).update!(vibe_check_url: "https://checks.every.to/opus-5")
    assert_equal %w[claude-opus-5 claude-opus-5-5], AiModel.launched.pluck(:slug).sort

    ai_models(:opus_5_5).update!(released_on: nil)
    assert_equal [ ai_models(:opus_5) ], AiModel.launched.to_a

    ai_models(:opus_5).update!(status: "hidden")
    assert_empty AiModel.launched
  end

  test "a link written past validation is never rendered" do
    model = ai_models(:opus_5_5)
    assert_equal "https://checks.every.to/vibe-checks/claude-opus-5-5", model.vibe_check_link

    model.update_column(:vibe_check_url, "https://evil.example/x")
    assert_nil model.vibe_check_link

    model.update_column(:vibe_check_url, nil)
    assert_nil model.vibe_check_link
  end

  test "to_prop carries the kind and the mark" do
    assert_equal({ slug: "claude-opus-5-5", name: "Claude Opus 5.5", kind: "model", maker: "Anthropic", mark: nil, pending: false }, ai_models(:opus_5_5).to_prop)
    assert_equal "tool", tools(:cursor).to_prop[:kind]

    tools(:cursor).update!(mark: "cursor")
    assert_equal "cursor", tools(:cursor).to_prop[:mark]
  end
end
