# frozen_string_literal: true

require "test_helper"

# Regression test for the process-wide Dir.chdir race behind the Inertia asset
# version (config/initializers/inertia_rails.rb).
#
# config.version calls ViteRuby.digest -> ViteRuby::Builder#watched_files_digest,
# which wraps its work in ViteRuby::Config#within_root -> Dir.chdir(root) { ... }.
# Block-form Dir.chdir is process-wide: Ruby permits only one active block at a
# time across the whole process, so a second thread entering while the first is
# inside raises
#
#   RuntimeError: conflicting chdir during another chdir block
#
# and the Inertia request that triggered it 500s.
#
# In production the overlap is intermittent — it needs one thread to yield the GVL
# while inside the block, which is why it shows up under load (downstream: 2 × 500
# out of 40 concurrent Inertia requests) rather than in ordinary testing. The first
# test below forces that overlap deterministically so the regression is caught
# every run, not one run in twenty. Remove the mutex from the initializer and it
# goes red.
class InertiaVersionThreadSafetyTest < ActiveSupport::TestCase
  setup { reset_vite_digest_memo! }

  test "a second thread is held off while the first is inside vite_ruby's chdir block" do
    inside_chdir = Queue.new
    release_error = nil

    # Hold the first caller inside the real Dir.chdir block long enough for a
    # second thread to arrive. Nothing here fakes the failure — the RuntimeError,
    # when it comes, is raised by Ruby's own chdir bookkeeping.
    with_slow_within_root(inside_chdir, hold_for: 0.2) do
      first = Thread.new { InertiaRails.configuration.version }

      # Provably inside the chdir block before the second thread starts.
      inside_chdir.pop

      second = Thread.new do
        InertiaRails.configuration.version
      rescue RuntimeError => e
        release_error = e
        nil
      end

      first_digest = first.value
      second_digest = second.value

      assert_nil release_error,
        "a concurrent Inertia version read hit the process-wide chdir race: #{release_error&.message}"
      assert_equal first_digest, second_digest,
        "concurrent reads disagreed on the asset version"
      assert_match(/\A[0-9a-f]{40}\z/, first_digest)
    end
  end

  test "many concurrent readers agree on one digest" do
    threads = 32.times.map { Thread.new { InertiaRails.configuration.version } }

    # Thread#value re-raises in the joining thread, so a conflicting-chdir
    # RuntimeError surfaces here as a test failure rather than a dead thread.
    digests = threads.map(&:value)

    assert_equal 1, digests.uniq.size,
      "concurrent reads disagreed on the asset version: #{digests.uniq.inspect}"
    assert_match(/\A[0-9a-f]{40}\z/, digests.first)
  end

  test "the version lambda returns a stable SHA1 digest" do
    version = InertiaRails.configuration.version

    assert_match(/\A[0-9a-f]{40}\z/, version)
    assert_equal version, InertiaRails.configuration.version
  end

  test "development and test recompute so a rebuilt frontend invalidates history" do
    assert Rails.env.local?, "this test only means something on the live-recompute path"

    with_counted_digest("a" * 40) do |calls|
      3.times { InertiaRails.configuration.version }

      assert_equal 3, calls.call,
        "development/test must re-read the digest on each call, not memoize it"
    end
  end

  # Note: this is the only test that takes the non-local branch, and doing so
  # leaves the initializer's memo populated for the rest of the process. A second
  # test on that branch would need to account for it.
  test "outside development and test the digest is computed once, not per request" do
    with_counted_digest("b" * 40) do |calls|
      with_env_local(false) do
        3.times { InertiaRails.configuration.version }
      end

      assert_equal 1, calls.call,
        "production must memoize the digest rather than glob + SHA1 on every request"
    end
  end

  private

  # Wraps the real within_root so the first caller parks inside the open chdir
  # block, signalling once it is there. Everything still runs through Ruby's real
  # Dir.chdir; only the dwell time is manufactured.
  def with_slow_within_root(signal, hold_for:)
    patched = false
    config = ViteRuby.config
    original = config.method(:within_root)
    held = false
    guard = Mutex.new

    config.define_singleton_method(:within_root) do |&block|
      original.call do
        first = guard.synchronize { held ? false : (held = true) }
        if first
          signal << :inside
          sleep hold_for
        end
        block.call
      end
    end
    patched = true

    yield
  ensure
    # Only undo what was actually installed — an unguarded remove_method would
    # raise NameError over the top of whatever really failed.
    config.singleton_class.send(:remove_method, :within_root) if patched
  end

  # Counts calls to ViteRuby.digest and hands the counter to the block. Minitest 6
  # dropped Object#stub and the repo carries no mocking gem, so the singleton
  # method is swapped by alias and the original delegator restored afterwards —
  # define/remove alone would delete the def_delegators entry for good.
  def with_counted_digest(value)
    aliased = false
    singleton = ViteRuby.singleton_class
    calls = 0

    singleton.send(:alias_method, :digest_before_stub, :digest)
    aliased = true
    singleton.send(:define_method, :digest) { calls += 1; value }

    yield -> { calls }
  ensure
    if aliased
      singleton.send(:alias_method, :digest, :digest_before_stub)
      singleton.send(:remove_method, :digest_before_stub)
    end
  end

  # Flips Rails.env.local? for the block. Rails.env is memoized, and local? is
  # defined on ActiveSupport::EnvironmentInquirer, so a singleton override removes
  # cleanly and reveals the real method again.
  def with_env_local(value)
    stubbed = false
    env = Rails.env
    env.define_singleton_method(:local?) { value }
    stubbed = true

    yield
  ensure
    env.singleton_class.send(:remove_method, :local?) if stubbed
  end

  # vite_ruby memoizes the digest for one second; a warm memo returns before
  # reaching Dir.chdir, which is where the race lives. Clearing it puts each test
  # back on the path under test. Reaches into gem internals deliberately; guarded
  # so a rename weakens the test's sensitivity instead of erroring.
  def reset_vite_digest_memo!
    builder = ViteRuby.instance.builder
    return unless builder.instance_variable_defined?(:@last_digest_at)

    builder.instance_variable_set(:@last_digest_at, nil)
  end
end
