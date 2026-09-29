# Prints the signed `session_id` cookie value (URL-escaped) for a seeded member, so the
# timing script can load signed-in pages without going through Sign in with Every.
user = User.find_by!(email_address: ENV.fetch("PERF_EMAIL", "kieran@every.to"))
session = user.sessions.create!(user_agent: "perf-harness", ip_address: "127.0.0.1")
request = ActionDispatch::Request.new(Rails.application.env_config.merge("HTTP_HOST" => "localhost", "rack.input" => StringIO.new))
jar = request.cookie_jar
jar.signed[:session_id] = session.id
puts CGI.escape(jar[:session_id])
