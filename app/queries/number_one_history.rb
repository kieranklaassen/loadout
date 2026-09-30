# frozen_string_literal: true

# What the team used before: the number-one tool and model in one kind of work, day by
# day back through history, collapsed into eras ("What we used before" on the Kind page).
# It is replayed from entry_changes on every read (KTD7) rather than stored, so a deleted
# person stops influencing it and each viewer gets their own answer.
#
#   eras = NumberOneHistory.new(viewer: Current.user, show: params[:show]).eras(category)
#
# Arguments
#   viewer:  a User, or nil for a signed-out visitor.
#   show:    "team" (default) or "others"; see Audience, which decides who is in the room.
#
# eras(category) returns [{ from:, to:, tool:, model: }], oldest first. from and to are UTC
# dates ("2026-03-02"), both days inclusive; tool and model are Mark items (CatalogItem#to_prop),
# and model is nil while nobody counted has one. An era ends when either leader changes. Days
# that do not count (below) neither start nor end an era: consecutive counted days with the
# same leaders are one era even across a gap. `to` is nil when the era runs through today, which
# makes it the current era and its leader the Kind table's; when fewer than MIN_PEOPLE counted
# today the last era ended on its `to` day and there is no current one. A Kind page shows the
# section when eras.size >= 2, and "since" is eras.last[:from] while eras.last[:to] is nil.
#
# The algorithm, per day and person:
#   1. Replay. Take the person's slot-changing rows for the kind (EntryChange::SLOT_ACTIONS
#      with a rank; legacy rows have none and suggested and dismissed rows never touch a slot)
#      in created_at, then id, order (ids only grow, so this is id order for anything the app
#      wrote). Rows sharing a time and details["batch"] apply together: first clear the slots
#      they remove or move away from, then set the rest. That gives the slots after each batch.
#   2. Cover. The person counts on a day only if they are in the viewer's population today
#      (Audience#ids: for the team every onboarded member, private ones anonymously; nobody
#      from the other SHOW class). A team member and the viewer are covered every day, the
#      same as the Kind table counts them. Anyone else counts only on days that overlap one
#      of their visibility periods at a level the viewer may read (Audience#levels), sampled
#      at the earlier of the day's end and the period's end, so edits made after narrowing
#      on the same day never count.
#   3. Count. A day counts only if at least MIN_PEOPLE covered people had a pick in the kind.
#      Only approved tools count (their model too, if approved); a person is a person once.
#   4. Lead. The leader is TeamRankings' rule: people, then 1st picks, then name (Audience.sort_key,
#      the item id last so ties are stable). Today's leader is therefore the Kind table's.
#
# Cost: one query for the rows (with their tools and models) and one for the periods, then
# arithmetic; a day is never a query.
class NumberOneHistory
  MIN_PEOPLE = 3

  attr_reader :audience

  # One person's slots after each batch of their rows: [[time, { rank => change row }], ...].
  # `changes` are slot-changing rows with a rank, in created_at then id order. Public so a
  # test can hold the replay to the person's entries.
  def self.timeline(changes)
    slots = {}
    changes.chunk_while { |a, b| a.created_at == b.created_at && a.details["batch"] == b.details["batch"] }.map do |batch|
      batch.each do |change|
        slots.delete(change.from_rank) if change.from_rank
        slots.delete(change.rank) if change.action == "removed"
      end
      batch.each { |change| slots[change.rank] = change unless change.action == "removed" }
      [ batch.first.created_at, slots.dup ]
    end
  end

  def initialize(viewer:, show: nil)
    @audience = Audience.new(viewer:, show:)
  end

  def eras(category)
    timelines = timelines_in(category)
    return [] if timelines.empty?

    today = Time.current.utc.to_date
    first_day = timelines.values.map { |timeline| timeline.first.first }.min.utc.to_date
    days = (first_day..today).filter_map { |date| leaders_on(date, timelines) }

    days.chunk_while { |a, b| a[1..] == b[1..] }.map do |run|
      date, tool, model = run.first
      last = run.last.first
      { from: date.iso8601, to: (last.iso8601 unless last == today), tool: tool.to_prop, model: model&.to_prop }
    end
  end

  private

  # { user_id => timeline } for the people in the room who ever changed a slot in the kind.
  def timelines_in(category)
    changes = EntryChange.where(category:, user_id: audience.ids, action: EntryChange::SLOT_ACTIONS).where.not(rank: nil)
      .includes(:tool, :ai_model).order(:created_at, :id)
    changes.group_by(&:user_id).transform_values { |rows| self.class.timeline(rows) }
  end

  # [date, tool leader, model leader] for a day that counts, else nil.
  def leaders_on(date, timelines)
    day_start = date.in_time_zone("UTC")
    day_end = day_start + 1.day
    picks = timelines.flat_map do |user_id, timeline|
      instant = sampled_until(user_id, day_start, day_end) or next []
      slots_before(timeline, instant).values.select { |change| change.tool.approved? }.map { |change| [ user_id, change ] }
    end
    return if picks.map(&:first).uniq.size < MIN_PEOPLE

    [ date, leader(picks, :tool), leader(picks.select { |_, change| change.ai_model&.approved? }, :ai_model) ]
  end

  # The instant to read a person's slots at on a day, or nil when they do not count that day.
  def sampled_until(user_id, day_start, day_end)
    return day_end if audience.team? || user_id == audience.viewer&.id

    periods.fetch(user_id, []).filter_map do |period|
      next unless period.starts_at < day_end && (period.ends_at.nil? || period.ends_at > day_start)

      [ period.ends_at, day_end ].compact.min
    end.max
  end

  # The periods the viewer may read, whatever the kind.
  def periods
    @periods ||= VisibilityPeriod.where(user_id: audience.ids, level: audience.levels).group_by(&:user_id)
  end

  # The slots as they stood before `instant`.
  def slots_before(timeline, instant)
    index = (timeline.bsearch_index { |time, _| time >= instant } || timeline.size) - 1
    index.negative? ? {} : timeline[index].last
  end

  # picks: [[user_id, change row]]. Nil when nobody has an item of that kind.
  def leader(picks, kind)
    picks.group_by { |_, change| change.public_send(kind) }.min_by do |item, holders|
      Audience.sort_key(holders.map(&:first).uniq.size, holders.count { |_, change| change.rank == 1 }, item.name) + [ item.id ]
    end&.first
  end
end
