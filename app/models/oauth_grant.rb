# One agent connection: a member approved a client, and it holds an access
# token (1 hour) and a rotating refresh token (30 days). Only digests are
# stored; the plaintext tokens exist in memory just long enough to answer the
# token request. Revoking the grant ends both tokens.
class OauthGrant < ApplicationRecord
  ACCESS_TTL = 1.hour
  REFRESH_TTL = 30.days

  belongs_to :user
  belongs_to :oauth_client
  has_many :oauth_authorization_codes, dependent: :nullify

  scope :active, -> { where(revoked_at: nil).where(refresh_expires_at: Time.current..) }

  before_validation :assign_new_tokens, on: :create

  attr_reader :access_token, :refresh_token

  def self.issue!(user:, client:, resource:, scope:)
    create!(user:, oauth_client: client, resource:, scope:)
  end

  def self.authenticate(access_token, resource:)
    return if access_token.blank?

    grant = includes(:user, :oauth_client).find_by(access_digest: OauthToken.digest(access_token))
    grant if grant && grant.revoked_at.nil? && grant.access_expires_at.future? && grant.resource == resource
  end

  def self.find_by_refresh_token(refresh_token)
    find_by(refresh_digest: OauthToken.digest(refresh_token)) if refresh_token.is_a?(String) && refresh_token.present?
  end

  # The grant a rotated-out refresh token belonged to. Presenting one means the
  # token leaked or was replayed (OAuth 2.1 §4.3.1), so the caller revokes it.
  def self.find_by_previous_refresh_token(refresh_token)
    find_by(previous_refresh_digest: OauthToken.digest(refresh_token)) if refresh_token.is_a?(String) && refresh_token.present?
  end

  def refreshable?
    revoked_at.nil? && refresh_expires_at.future?
  end

  # Swaps both tokens. Returns false when another request rotated first, which
  # the caller treats as refresh-token reuse.
  def rotate!
    presented = refresh_digest
    assign_new_tokens
    self.previous_refresh_digest = presented
    rows = self.class.where(id:, refresh_digest: presented, revoked_at: nil)
      .update_all(attributes.slice(*%w[access_digest access_expires_at refresh_digest refresh_expires_at previous_refresh_digest]).merge("updated_at" => Time.current))
    rows == 1
  end

  def revoke!
    update!(revoked_at: Time.current) if revoked_at.nil?
  end

  def token_response
    raise "tokens are only available right after they are issued" unless access_token && refresh_token

    {
      access_token:, token_type: "Bearer", expires_in: ACCESS_TTL.to_i,
      refresh_token:, scope:
    }
  end

  private
    def assign_new_tokens
      @access_token = OauthToken.generate("lo_at")
      @refresh_token = OauthToken.generate("lo_rt")
      now = Time.current
      self.access_digest = OauthToken.digest(@access_token)
      self.access_expires_at = now + ACCESS_TTL
      self.refresh_digest = OauthToken.digest(@refresh_token)
      self.refresh_expires_at = now + REFRESH_TTL
    end
end
