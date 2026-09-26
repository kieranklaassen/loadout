# A one-time authorization code from the consent screen. It lives 60 seconds,
# is bound to its client, redirect URI, PKCE challenge, and resource, and is
# stored only as a digest.
class OauthAuthorizationCode < ApplicationRecord
  TTL = 60.seconds

  belongs_to :oauth_client
  belongs_to :user
  belongs_to :oauth_grant, optional: true

  attr_reader :code

  def self.issue!(client:, user:, redirect_uri:, code_challenge:, resource:, scope:)
    code = OauthToken.generate("lo_ac")
    create!(
      oauth_client: client, user:, redirect_uri:, code_challenge:, resource:, scope:,
      code_digest: OauthToken.digest(code), expires_at: TTL.from_now
    ).tap { |record| record.instance_variable_set(:@code, code) }
  end

  def self.find_by_code(code)
    find_by(code_digest: OauthToken.digest(code)) if code.is_a?(String) && code.present?
  end

  # Marks the code used. Only one caller can ever win, even when two token
  # requests race; the loser must treat the code as replayed.
  def claim!
    now = Time.current
    self.class.where(id:, used_at: nil).update_all(used_at: now, updated_at: now) == 1
  end

  def expired?
    expires_at <= Time.current
  end
end
