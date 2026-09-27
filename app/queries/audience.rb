# frozen_string_literal: true

# Who is in the room for one viewer. Every page and tool that names a person or
# counts one asks here first, so there is one answer to "who may this viewer see".
#
#   audience = Audience.new(viewer: Current.user, show: params[:show], person: params[:person])
#
# Arguments
#   viewer:  a User, or nil for a signed-out visitor.
#   show:    "team" (verified @every.to, the default) or "others" (the rest of the people
#            the viewer may open). "subscribers" has no data behind it yet and, like any
#            unknown value, falls back to the team; subscribers also sets a notice.
#   person:  a handle. It only takes effect for someone in the population below; a hidden
#            person, an unknown handle and a person in the other SHOW class all behave as nil.
#
# The population P is the people the viewer may open (User.visible_to, which owns the
# visibility rule) who have at least one confirmed pick on an approved tool, in the SHOW
# class. M is its size. The viewer counts as themselves even when they share with nobody
# (includes_private_picks? says when the count contains picks colleagues cannot see).
# Suggestions, hidden people and pending or hidden catalog items count nowhere.
#
# Public methods
#   viewer, show, notice, person         the normalised inputs (person is a User or nil)
#   filters                              { show:, person: handle or nil }, for the Home filters prop
#   people                               PERSON options: [{ handle:, name: }], in name order
#   size / empty?                        M
#   ids, entries                         the people, and their picks that may count (used by TeamRankings)
#   person_ref(user_id)                  the { handle:, name: } entry for someone in the population
#   levels                               the visibility levels the viewer may read (for period clipping)
#   includes_private_picks?              the viewer is counted and nobody else can open them
#   Audience.person(user)                the { handle:, name: } entry used everywhere a person is named
#   Audience.sort_key(count, firsts, name)  the one ranking comparator: people, then 1st picks, then name
class Audience
  # The SHOW classes that have people in them, and everything SHOW offers (subscribers is a stub).
  CLASSES = %w[team others].freeze
  SHOWS = (CLASSES + [ "subscribers" ]).freeze
  DEFAULT_SHOW = "team"
  # No data source for Every subscribers exists yet; SHOW still offers it as a disabled stub.
  SUBSCRIBERS_AVAILABLE = false
  SUBSCRIBERS_NOTICE = "Every subscribers are not available yet, so this shows the Every team."

  attr_reader :viewer, :show, :notice

  class << self
    # The entry for a person in any list. Never carries email, bio or avatar.
    def person(user)
      { handle: user.handle, name: user.name.presence || user.handle }
    end

    # People first, then how many put it 1st, then name. One comparator on every surface.
    def sort_key(count, firsts, name)
      [ -count, -firsts, name.to_s.downcase ]
    end

    # Picks that may count anywhere: an approved tool. (A model counts only if it is approved too.)
    def counted_entries
      Entry.joins(:tool).merge(Tool.approved)
    end
  end

  def initialize(viewer:, show: nil, person: nil)
    @viewer = viewer
    requested = show.to_s.strip.downcase
    @show = CLASSES.include?(requested) ? requested : DEFAULT_SHOW
    @notice = SUBSCRIBERS_NOTICE if requested == "subscribers" && !SUBSCRIBERS_AVAILABLE
    @person_handle = person.to_s.strip.downcase
  end

  def person
    members.find { |user| user.handle == @person_handle } if @person_handle.present?
  end

  def filters
    { show:, person: person&.handle }
  end

  def people
    members.map { |user| self.class.person(user) }
  end

  def ids
    members.map(&:id)
  end

  def size
    members.size
  end

  def empty?
    members.empty?
  end

  def person_ref(user_id)
    self.class.person(members_by_id.fetch(user_id))
  end

  # The confirmed picks of the population that may count.
  def entries
    self.class.counted_entries.where(user_id: ids)
  end

  def levels
    User.levels_visible_to(viewer)
  end

  def includes_private_picks?
    viewer.present? && members.any? { |user| user.id == viewer.id } && !viewer.shared?
  end

  private

  # In name order, so every list built from it is.
  def members
    @members ||= begin
      openable = User.visible_to(viewer).where(id: self.class.counted_entries.select(:user_id))
      openable = team? ? openable.every_members : openable.where.not(id: User.every_members.select(:id))
      openable.sort_by { |user| [ user.name.to_s.downcase, user.handle.to_s ] }
    end
  end

  def members_by_id
    @members_by_id ||= members.index_by(&:id)
  end

  def team? = show == "team"
end
