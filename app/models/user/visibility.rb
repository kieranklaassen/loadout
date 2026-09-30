# Who may open a person's page: only them (the default), the Every team, or anyone
# with the link. This is the one place that compares visibility values; everything
# that shows a person, counts them or names them asks visible_to? or User.visible_to.
#
# Every span a person shared is recorded in visibility_periods, so history can
# later count them only on days they were sharing. The callback keeps the periods
# in step with the column in the same transaction, so no controller, seed or
# console session can change one without the other. Model rules validate the
# level, and that a shared page has a handle: a database check on users would make
# SQLite rebuild the table.
module User::Visibility
  extend ActiveSupport::Concern

  SHARING_LEVELS = %w[team link].freeze
  LEVELS = ([ "only_me" ] + SHARING_LEVELS).freeze
  # What a new member starts with once they claim a handle. The column default stays
  # only_me because a member is created at first sign-in, before a handle exists, and a
  # shared page needs one.
  ONBOARDING_VISIBILITY = "link"

  included do
    has_many :visibility_periods, dependent: :delete_all

    validates :visibility, inclusion: { in: LEVELS }
    validate :shared_page_has_handle

    after_save :record_visibility_period, if: :saved_change_to_visibility?

    # The people the viewer may open (nil for a signed-out visitor), themselves included.
    scope :visible_to, ->(viewer) {
      shared = where(visibility: levels_visible_to(viewer))
      viewer ? shared.or(where(id: viewer.id)) : shared
    }
  end

  class_methods do
    # Team viewers (verified @every.to) see team and link pages; everyone else, signed in or not, link pages.
    def levels_visible_to(viewer)
      viewer&.every_member? ? SHARING_LEVELS : [ "link" ]
    end
  end

  # An unknown stored value is visible to no one but the owner.
  def visible_to?(viewer)
    viewer == self || self.class.levels_visible_to(viewer).include?(visibility)
  end

  # Whether anyone besides the owner may open this page (false for only me and unknown values).
  def shared?
    SHARING_LEVELS.include?(visibility)
  end

  private

  # A shared page lives at its handle, so sharing waits for a claimed link and a
  # shared page keeps one.
  def shared_page_has_handle
    errors.add(:visibility, "needs a claimed link before you share your page") if shared? && handle.blank?
  end

  def record_visibility_period
    now = Time.current
    visibility_periods.where(ends_at: nil).update_all(ends_at: now)
    visibility_periods.create!(level: visibility, starts_at: now) if SHARING_LEVELS.include?(visibility)
  end
end
