class User < ApplicationRecord
  include EveryIdentity
  include Handle
  include Visibility

  # Replaced by visibility; a leftover reader should fail loudly, and a later
  # migration drops the column (a drop rebuilds users on SQLite, which is unsafe).
  self.ignored_columns += %w[public]

  has_many :sessions, dependent: :destroy
  has_many :entries, dependent: :delete_all
  has_many :entry_changes, dependent: :delete_all
  has_many :pick_suggestions, dependent: :delete_all
  has_many :oauth_authorization_codes, dependent: :delete_all
  has_many :oauth_grants, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :every_user_id, with: ->(id) { id.strip.presence }
  normalizes :bio, with: ->(bio) { bio.squish.presence }

  validates :email_address, presence: true, uniqueness: true
  validates :bio, length: { maximum: 160 }

  def display_name
    name.presence || handle.presence || email_address.split("@").first
  end

  def onboarded?
    handle.present? && onboarded_at.present?
  end

  def admin?
    super || admin_email?
  end

  private

  # An address in ADMIN_EMAILS grants admin once an Every sign-in verified it
  # (any sign-in without an explicit email_verified false).
  def admin_email?
    email_verified? && ENV.fetch("ADMIN_EMAILS", "").split(",").map { |email| email.strip.downcase }.include?(email_address)
  end
end
