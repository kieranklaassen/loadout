require "test_helper"
require "open3"
require "tmpdir"

# Runs the real bin/docker-entrypoint in a scratch directory with a stand-in
# ./bin/rails that records what it was asked to do, and the real sqlite3 CLI
# (installed in the image) for the backup.
class DockerEntrypointTest < ActiveSupport::TestCase
  ENTRYPOINT = Rails.root.join("bin/docker-entrypoint").to_s

  FAKE_RAILS = <<~'SH'
    #!/bin/bash
    case "$1" in
      db:abort_if_pending_migrations)
        echo "pending-check" >> calls.log
        exit "${FAKE_PENDING_EXIT:-0}" ;;
      db:prepare)
        echo "prepare backups=$(ls storage/backup-* 2>/dev/null | wc -l | tr -d ' ')" >> calls.log
        [ -f storage/production.sqlite3 ] && sqlite3 storage/production.sqlite3 "DELETE FROM users"
        exit "${FAKE_PREPARE_EXIT:-0}" ;;
      runner)
        echo "runner $2" >> calls.log
        exit "${FAKE_RUNNER_EXIT:-0}" ;;
      *)
        echo "$*" >> calls.log ;;
    esac
  SH

  setup do
    skip "the sqlite3 command line tool is not installed" unless system("sqlite3", "-version", out: File::NULL)
    @dir = Dir.mktmpdir("entrypoint")
    FileUtils.mkdir_p(File.join(@dir, "bin"))
    FileUtils.mkdir_p(File.join(@dir, "storage"))
    File.write(File.join(@dir, "bin/rails"), FAKE_RAILS, perm: 0o755)
  end

  teardown { FileUtils.remove_entry(@dir) if @dir }

  test "with migrations pending it takes a private, consistent backup before migrating, then prepares, syncs and starts the server" do
    create_database
    result = run_entrypoint("./bin/rails", "server", "FAKE_PENDING_EXIT" => "1")

    assert result.success?, result.stderr
    assert_equal [ "pending-check", "prepare backups=1", "runner Catalog::Sync.call", "server" ], calls
    backup = Dir[File.join(@dir, "storage/backup-*")].sole
    assert_equal "600", format("%o", File.stat(backup).mode & 0o777)
    assert_equal [ "ana@every.to", "dee@every.to" ], query(backup, "SELECT email FROM users ORDER BY email"), "the copy holds what the migration is about to change"
    assert_empty query(File.join(@dir, "storage/production.sqlite3"), "SELECT email FROM users")
    assert_match(/Backed up/, result.stderr)
  end

  test "with nothing pending it makes no backup but still prepares and syncs" do
    create_database

    result = run_entrypoint("./bin/rails", "server")

    assert result.success?, result.stderr
    assert_equal [ "pending-check", "prepare backups=0", "runner Catalog::Sync.call", "server" ], calls
    assert_empty Dir[File.join(@dir, "storage/backup-*")]
  end

  test "on a first deploy there is no database to back up or to check" do
    result = run_entrypoint("./bin/rails", "server")

    assert result.success?, result.stderr
    assert_equal [ "prepare backups=0", "runner Catalog::Sync.call", "server" ], calls
  end

  test "a failed catalog sync is logged and the server still starts" do
    result = run_entrypoint("./bin/rails", "server", "FAKE_RUNNER_EXIT" => "1")

    assert result.success?, result.stderr
    assert_equal [ "prepare backups=0", "runner Catalog::Sync.call", "server" ], calls
    assert_match(/Catalog sync failed/, result.stderr)
  end

  test "a failed migration stops the boot before the catalog sync and the server" do
    create_database

    result = run_entrypoint("./bin/rails", "server", "FAKE_PENDING_EXIT" => "1", "FAKE_PREPARE_EXIT" => "1")

    assert_not result.success?
    assert_equal [ "pending-check", "prepare backups=1" ], calls
  end

  test "a failed backup stops the boot before migrating, and the database is untouched" do
    create_database
    database = File.join(@dir, "storage/production.sqlite3")
    before = File.binread(database)
    failing = File.join(@dir, "failing-backup")
    FileUtils.mkdir_p(failing)
    # First on PATH: fails .backup, and hands anything else to the real sqlite3 so a
    # db:prepare that ran anyway would still change the database.
    File.write(File.join(failing, "sqlite3"), <<~'SH', perm: 0o755)
      #!/bin/bash
      [[ "$2" == .backup* ]] && { echo "Error: disk I/O error" >&2; exit 1; }
      PATH="${PATH#*:}" exec sqlite3 "$@"
    SH

    result = run_entrypoint("./bin/rails", "server", "FAKE_PENDING_EXIT" => "1", "PATH" => "#{failing}:#{ENV["PATH"]}")

    assert_not result.success?
    assert_equal [ "pending-check" ], calls
    assert_equal before, File.binread(database)
    assert_no_match(/Backed up/, result.stderr)
  end

  test "other commands run untouched" do
    create_database

    result = run_entrypoint("./bin/rails", "console")

    assert result.success?, result.stderr
    assert_equal [ "console" ], calls
    assert_empty Dir[File.join(@dir, "storage/backup-*")]
  end

  private

  Result = Struct.new(:stdout, :stderr, :status) do
    def success? = status.success?
  end

  def run_entrypoint(*command, **env)
    stdout, stderr, status = Open3.capture3(env.transform_keys(&:to_s).merge("RAILS_ENV" => "production"), ENTRYPOINT, *command, chdir: @dir)
    Result.new(stdout, stderr, status)
  end

  def calls
    File.readlines(File.join(@dir, "calls.log"), chomp: true)
  end

  def create_database
    path = File.join(@dir, "storage/production.sqlite3")
    system("sqlite3", path, "CREATE TABLE users (email TEXT); INSERT INTO users VALUES ('ana@every.to'), ('dee@every.to')", exception: true)
  end

  def query(path, sql)
    IO.popen([ "sqlite3", path, sql ], &:read).split("\n")
  end
end
