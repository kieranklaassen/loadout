# The Every side of a User: the provider id UserInfo returns and the profile
# snapshot. Rows are created by the first successful Every sign-in. Anyone with
# an every.to account may sign in; people with an @every.to address are Every
# members and feed the Every map.
module User::EveryIdentity
  extend ActiveSupport::Concern

  EVERY_EMAIL_DOMAIN = "every.to"

  included do
    validates :every_user_id, uniqueness: true, allow_nil: true
    scope :every_members, -> { where("email_address LIKE ?", "%@#{EVERY_EMAIL_DOMAIN}") }
  end

  class_methods do
    # Exact, case-insensitive domain match on the normalized address, so
    # "ana@every.to.evil.com" and "ana@sub.every.to" do not count.
    def every_email?(email)
      parts = email.to_s.strip.downcase.split("@", -1)
      parts.size == 2 && parts.first.present? && parts.last == EVERY_EMAIL_DOMAIN
    end

    # Upserts the user for a verified UserInfo identity. Identity is keyed by
    # every_user_id; only a row without an Every identity yet (the dev seeds)
    # with the same email is adopted, so a new Every account can never take over
    # an existing SSO user's row through a reused email. Email, name, and avatar
    # follow the provider.
    def from_every_auth!(uid:, email:, name:, image:)
      user = find_by(every_user_id: uid) || find_by(email_address: email.to_s.strip.downcase, every_user_id: nil) || new
      user.update!(every_user_id: uid, email_address: email, name: name.presence, avatar_url: image.presence)
      user
    end
  end

  def every_member?
    self.class.every_email?(email_address)
  end
end
