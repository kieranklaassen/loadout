# Random secrets for the MCP OAuth server: authorization codes, access tokens,
# and refresh tokens. Only SHA-256 digests are stored, so a database leak
# yields nothing an agent could present.
module OauthToken
  PKCE_VERIFIER = /\A[A-Za-z0-9\-._~]{43,128}\z/

  module_function

  def generate(prefix)
    "#{prefix}_#{SecureRandom.urlsafe_base64(32)}"
  end

  def digest(value)
    OpenSSL::Digest::SHA256.hexdigest(value.to_s)
  end

  # RFC 7636 S256: BASE64URL(SHA256(verifier)) without padding.
  def pkce_match?(verifier, challenge)
    return false unless verifier.is_a?(String) && verifier.match?(PKCE_VERIFIER) && challenge.is_a?(String)

    computed = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(computed, challenge)
  end
end
