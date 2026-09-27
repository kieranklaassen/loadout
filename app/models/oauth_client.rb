# An MCP client (Claude, Cursor, Codex) registered through RFC 7591 dynamic
# client registration. Every client is public: it has no secret, so PKCE and an
# exactly matching redirect URI are what bind a code to it.
class OauthClient < ApplicationRecord
  LOOPBACK_HOSTS = %w[127.0.0.1 localhost ::1].freeze
  BLOCKED_SCHEMES = %w[javascript data file vbscript blob about filesystem view-source ws wss ftp mailto tel sms].freeze
  PRIVATE_USE_SCHEME = /\A[a-z][a-z0-9+.\-]*\z/
  MAX_REDIRECT_URIS = 10

  has_many :oauth_authorization_codes, dependent: :delete_all
  has_many :oauth_grants, dependent: :delete_all

  normalizes :client_name, with: ->(name) { name.gsub(/[[:cntrl:]]/, " ").squish }

  before_validation -> { self.client_id ||= SecureRandom.urlsafe_base64(24) }, on: :create

  validates :client_id, presence: true, uniqueness: true
  validates :client_name, presence: true, length: { maximum: 100 }
  validates :software_id, :software_version, length: { maximum: 200 }
  validate :redirect_uris_are_allowed
  validate :links_are_https

  # nil when the URI may be registered, otherwise why not: https, loopback http
  # on any port (RFC 8252), or a private-use scheme like cursor:// or vscode://.
  def self.redirect_uri_error(value)
    return "must be a string" unless value.is_a?(String)
    return "is too long" if value.length > 2000
    return "must not contain a fragment" if value.include?("#")

    uri = URI.parse(value)
    scheme = uri.scheme.to_s.downcase
    return "must be an absolute URI" if scheme.empty?
    return "must not contain credentials" if uri.userinfo

    case scheme
    when "https" then "needs a host" if uri.host.blank?
    when "http" then "must use https unless it points at a loopback address" unless loopback?(uri)
    else "uses a scheme that is not allowed" if BLOCKED_SCHEMES.include?(scheme) || !scheme.match?(PRIVATE_USE_SCHEME)
    end
  rescue URI::InvalidURIError
    "is not a valid URI"
  end

  def self.loopback?(uri)
    uri.scheme&.downcase == "http" && LOOPBACK_HOSTS.include?(uri.hostname.to_s.downcase)
  end

  # Exact match, except that a loopback redirect may use any port (RFC 8252 §7.3),
  # because native clients bind an ephemeral port per sign-in.
  def redirect_uri_registered?(candidate)
    return false unless candidate.is_a?(String) && self.class.redirect_uri_error(candidate).nil?

    Array(redirect_uris).any? { |registered| registered == candidate || loopback_port_variant?(registered, candidate) }
  end

  private
    def loopback_port_variant?(registered, candidate)
      a = URI.parse(registered)
      b = URI.parse(candidate)
      self.class.loopback?(a) && self.class.loopback?(b) &&
        a.hostname.downcase == b.hostname.downcase && a.path == b.path && a.query == b.query
    rescue URI::InvalidURIError
      false
    end

    def redirect_uris_are_allowed
      uris = redirect_uris
      unless uris.is_a?(Array) && uris.any? && uris.size <= MAX_REDIRECT_URIS
        return errors.add(:redirect_uris, "must list between 1 and #{MAX_REDIRECT_URIS} URIs")
      end

      uris.each do |uri|
        problem = self.class.redirect_uri_error(uri)
        errors.add(:redirect_uris, "#{uri.to_s.truncate(100).inspect} #{problem}") if problem
      end
    end

    def links_are_https
      { client_uri:, logo_uri: }.each do |attribute, value|
        next if value.blank?

        uri = URI.parse(value) rescue nil
        errors.add(attribute, "must be an https URL") unless value.length <= 2000 && uri.is_a?(URI::HTTPS) && uri.host.present?
      end
    end
end
