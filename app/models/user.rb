class User < ApplicationRecord
  include EveryIdentity
  include Handle

  has_many :sessions, dependent: :destroy
  has_many :entries, dependent: :delete_all
  has_many :entry_changes, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :every_user_id, with: ->(id) { id.strip.presence }
  normalizes :bio, with: ->(bio) { bio.squish.presence }

  validates :email_address, presence: true, uniqueness: true
  validates :bio, length: { maximum: 160 }

  scope :publicly_visible, -> { where(public: true).where.not(handle: nil) }

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

  def admin_email?
    ENV.fetch("ADMIN_EMAILS", "").split(",").map { |email| email.strip.downcase }.include?(email_address)
  end
end
