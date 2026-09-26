class User < ApplicationRecord
  # bcrypt silently truncates anything past 72 bytes, so a longer password would
  # authenticate on its first 72 bytes — reject it explicitly instead.
  MAXIMUM_PASSWORD_BYTES = 72
  MINIMUM_PASSWORD_LENGTH = 12

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true
  validate :password_within_bcrypt_limit

  private

  def password_within_bcrypt_limit
    return if password.blank?
    return if password.bytesize <= MAXIMUM_PASSWORD_BYTES

    errors.add(:password, "must be #{MAXIMUM_PASSWORD_BYTES} bytes or fewer")
  end
end
