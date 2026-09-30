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
# Two sets of people, both limited to those with at least one confirmed pick on an approved
# tool, in the SHOW class:
#   named    the people the viewer may open (User.visible_to, which owns the visibility
#            rule), themselves included. Only they are ever named, linked or searchable.
#   counted  the population P that every count is taken over; M is its size. For "team" it
#            is every onboarded Every team member whatever their visibility, plus the viewer:
#            a private member's picks count anonymously and the member is never named. For
#            "others" it is the named people, so outside the team visibility still decides.
# The viewer counts as themselves even when they share with nobody (includes_private_picks?
# says when the count contains the viewer's own private picks). Suggestions and pending or
# hidden catalog items count nowhere.
#
# Privacy trade-off: counts over everyone can narrow a private person down. With one private
# member, "N of M" minus the named holders is that member's pick. Names never leak; the
# number is the price of the totals reflecting the whole team.
#
# Public methods
#   viewer, show, notice, person         the normalised inputs (person is a User or nil)
#   filters                              { show:, person: handle or nil }, for the Home filters prop
#   people                               PERSON options: [{ handle:, name: }], the named people in name order
#   size / empty?                        M
#   ids, entries                         the counted people, and their picks that may count (used by TeamRankings)
#   named_ids                            the named people's ids (search)
#   person_ref(user_id)                  the { handle:, name: } entry for a named person, nil for anyone else
#   levels                               the visibility levels the viewer may read (for period clipping)
#   includes_private_picks?              the viewer is counted and nobody else can open them
#   Audience.person(user)                the { handle:, name: } entry used everywhere a person is named
#   Audience.sort_key(count, firsts, name)  the one ranking comparator: people, then 1st picks, then name
#   Audience.name_key(name, handle)      the one order for people: name, then handle
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

    # Name, then handle. One order for every list of people.
    def name_key(name, handle)
      [ name.to_s.downcase, handle.to_s ]
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
    named.find { |user| user.handle == @person_handle } if @person_handle.present?
  end

  def filters
    { show:, person: person&.handle }
  end

  def people
    named.map { |user| self.class.person(user) }
  end

  def ids
    counted.map(&:id)
  end

  def named_ids
    named.map(&:id)
  end

  def size
    counted.size
  end

  def empty?
    counted.empty?
  end

  def person_ref(user_id)
    named_by_id[user_id]&.then { |user| self.class.person(user) }
  end

  # The confirmed picks of the population that may count.
  def entries
    self.class.counted_entries.where(user_id: ids)
  end

  def levels
    User.levels_visible_to(viewer)
  end

  def includes_private_picks?
    viewer.present? && counted.any? { |user| user.id == viewer.id } && !viewer.shared?
  end

  def team? = show == "team"

  private

  # In name order, so every list built from it is.
  def named
    @named ||= begin
      openable = User.visible_to(viewer).where(id: self.class.counted_entries.select(:user_id))
      # On the team only onboarded members count, so only they (and the viewer) are named: M is the same for every viewer.
      openable = team? ? openable.every_members.merge(User.onboarded.or(User.where(id: viewer&.id))) : openable.where.not(id: User.every_members.select(:id))
      openable.sort_by { |user| self.class.name_key(user.name, user.handle) }
    end
  end

  def counted
    @counted ||= if team?
      everyone = User.every_members.onboarded.where(id: self.class.counted_entries.select(:user_id)).to_a
      (named + everyone).uniq(&:id).sort_by { |user| self.class.name_key(user.name, user.handle) }
    else
      named
    end
  end

  def named_by_id
    @named_by_id ||= named.index_by(&:id)
  end
end
