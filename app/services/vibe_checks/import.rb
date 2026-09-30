# frozen_string_literal: true

# Writes what Every's Vibe Checks say each team member used into their dated history,
# so "What we used before" reaches back past the day they first ranked in Toolbox.
# Reads config/vibe_checks.yml (see the comment at its top); run on every deploy after
# Catalog::Sync, and safe to run again: it replaces every row it wrote before
# (source "vibe_check") and never touches entries, suggestions or rows from anywhere else.
#
# A snapshot is a person's ranked picks for one kind on the day a Vibe Check quoted
# them. It holds until the next snapshot of that kind, their first change of their own
# in the kind, or STALE_AFTER, whichever comes first; then a closing batch empties the
# slots again. History replays to a person's entries (KTD7), and the closing batch is
# what keeps that true: Toolbox picks start from an empty kind, as they did.
#
# Only a verified @every.to member counts, found by email or else by name; anyone not
# signed up yet is skipped and picked up by the next run after they sign in.
module VibeChecks
  class Import
    PATH = Rails.root.join("config/vibe_checks.yml")
    SOURCE = "vibe_check"
    STALE_AFTER = 90.days
    # Noon UTC, so a snapshot falls on its article's date in any time zone the app shows.
    HOUR = 12

    class Error < StandardError; end

    Snapshot = Data.define(:at, :url, :category, :picks)
    Pick = Data.define(:tool, :ai_model)

    def self.call(path: PATH, now: Time.current) = new(path:, now:).call

    def self.data(path = PATH)
      YAML.safe_load_file(path, permitted_classes: [ Date ]) || {}
    end

    def initialize(path: PATH, now: Time.current)
      @data = self.class.data(path)
      @now = now
    end

    # Returns { "person@every.to" => rows written } for the members it found.
    # The whole file is read and checked before anything is written.
    def call
      people = snapshots_by_person
      team = User.where(email_verified: true).where("email_address LIKE ?", "%@every.to").to_a

      people.each_with_object({}) do |(email, (name, snapshots)), written|
        member = team.find { |user| user.email_address == email.downcase } || team.find { |user| name.present? && user.name == name }
        next unless member

        ApplicationRecord.transaction do
          member.entry_changes.where(source: SOURCE).delete_all
          written[member.email_address] = snapshots.group_by(&:category).sum { |category, kind_snapshots| replay(member, category, kind_snapshots) }
        end
      end
    end

    private

    # { email => [name, [Snapshot]] }
    def snapshots_by_person
      @data.fetch("people", {}).to_h do |email, person|
        [ email, [ person["name"], person.fetch("snapshots", []).map { |attrs| snapshot(email, attrs) } ] ]
      end
    end

    def snapshot(email, attrs)
      date = attrs.fetch("date")
      raise Error, "#{email}: `date` must be a date, got #{date.inspect}" unless date.is_a?(Date)

      category = Category.find_by(slug: attrs.fetch("kind")) || raise(Error, "#{email}: no kind #{attrs["kind"].inspect}")
      picks = Array(attrs["picks"]).map { |pick| Pick.new(tool: find(Tool, pick.fetch("tool"), email), ai_model: (find(AiModel, pick["model"], email) if pick["model"])) }
      raise Error, "#{email}: at most #{Entry::MAX_RANK} picks for #{category.slug} on #{date}" if picks.size > Entry::MAX_RANK
      raise Error, "#{email}: a tool appears twice for #{category.slug} on #{date}" if picks.map(&:tool).uniq.size < picks.size

      Snapshot.new(at: date.in_time_zone("UTC").change(hour: HOUR), url: attrs.fetch("url"), category:, picks:)
    end

    def find(klass, slug, email)
      klass.find_by(slug:) || raise(Error, "#{email}: no #{klass.model_name.human.downcase} #{slug.inspect} in the catalog")
    end

    # Writes one member's snapshots for one kind and returns how many rows it wrote.
    def replay(member, category, snapshots)
      cutoff = [ first_own_change(member, category), @now ].compact.min
      slots = {}
      held_since = nil
      rows = 0

      snapshots.sort_by(&:at).select { |snapshot| snapshot.at < cutoff }.each do |snapshot|
        rows += write(member, category, slots, {}, at: held_since + STALE_AFTER, url: snapshot.url, closing: true) if held_since && held_since + STALE_AFTER < snapshot.at
        rows += write(member, category, slots, snapshot.picks.each_with_index.to_h { |pick, index| [ index + 1, pick ] }, at: snapshot.at, url: snapshot.url)
        held_since = snapshot.at
      end
      return rows unless held_since

      closed_at = [ held_since + STALE_AFTER, cutoff - 1.second ].min
      rows + write(member, category, slots, {}, at: closed_at, url: snapshots.max_by(&:at).url, closing: true)
    end

    def first_own_change(member, category)
      member.entry_changes.where(category:, action: EntryChange::SLOT_ACTIONS).where.not(source: SOURCE).minimum(:created_at)
    end

    # One batch taking `slots` (rank => Pick, changed in place) to `target`: a `removed`
    # row per slot emptied and a `set` row per slot that now holds something else.
    def write(member, category, slots, target, at:, url:, closing: false)
      details = { batch: "vibe-check-#{Digest::SHA256.hexdigest("#{url} #{category.slug} #{at.to_i}").first(16)}", vibe_check: url }
      details[:closing] = true if closing

      changes = (1..Entry::MAX_RANK).filter_map do |rank|
        next if slots[rank] == target[rank]

        pick = target[rank] || slots[rank]
        { action: target[rank] ? "set" : "removed", rank:, tool: pick.tool, ai_model: pick.ai_model }
      end

      changes.each do |change|
        member.entry_changes.create!(category:, source: SOURCE, created_at: at, details:, **change)
      end
      slots.replace(target)
      changes.size
    end
  end
end
