# The Every side of a User: the provider id UserInfo returns and the profile
# snapshot. Rows are created by the first successful Every sign-in. Anyone with
# an every.to account may sign in; only a verified @every.to address makes them
# part of the Every team, which is what opens team-only pages.
module User::EveryIdentity
  extend ActiveSupport::Concern

  EVERY_EMAIL_DOMAIN = "every.to"

  included do
    validates :every_user_id, uniqueness: true, allow_nil: true

    # The SQL twin of every_member?: verified, exactly one "@", something before it,
    # and the domain exactly every.to (LIKE is case-insensitive for ASCII).
    scope :every_members, -> {
      where(email_verified: true)
        .where("email_address LIKE ?", "_%@#{EVERY_EMAIL_DOMAIN}")
        .where("length(email_address) - length(replace(email_address, '@', '')) = 1")
    }
  end

  class_methods do
    # Exact, case-insensitive domain match on the normalized address, so
    # "ana@every.to.evil.com", "a@b@every.to" and "ana@sub.every.to" do not count.
    def every_email?(email)
      parts = email.to_s.strip.downcase.split("@", -1)
      parts.size == 2 && parts.first.present? && parts.last == EVERY_EMAIL_DOMAIN
    end

    # Upserts the user for a UserInfo identity. Identity is keyed by every_user_id;
    # only a row without an Every identity yet (the dev seeds) with the same email is
    # adopted, so a new Every account can never take over an existing SSO user's row
    # through a reused email. Email, name, avatar and whether the provider verified
    # the email follow the provider on every sign-in.
    def from_every_auth!(uid:, email:, name:, image:, email_verified:)
      user = find_by(every_user_id: uid) || find_by(email_address: email.to_s.strip.downcase, every_user_id: nil) || new
      user.update!(every_user_id: uid, email_address: email, name: name.presence, avatar_url: image.presence, email_verified:)
      user
    end
  end

  # On the Every team: a verified @every.to address.
  def every_member?
    email_verified? && self.class.every_email?(email_address)
  end
end
