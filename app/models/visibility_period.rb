# One span during which a person shared their page at a level (team or link).
# Only sharing is recorded: a person who was "Only me" has no period for that time.
# User::Visibility opens and closes these; history counts a person only on days a
# period covers.
class VisibilityPeriod < ApplicationRecord
  belongs_to :user

  validates :level, inclusion: { in: User::Visibility::SHARING_LEVELS }
  validates :starts_at, presence: true
end
