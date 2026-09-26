# One-click sign-in as a seeded every.to person, for local development only.
# Its routes are drawn only in development (config/routes/dev_login.rb) and the
# action answers 404 in any other environment, two independent guards.
class DevLogin::SessionsController < InertiaController
  allow_unauthenticated_access
  before_action :require_development

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
    return redirect_to new_session_path, alert: "Pick a seeded person from the list." if user.nil?

    start_new_session_for user
    redirect_to after_authentication_url, status: :see_other
  end

  private

  def require_development
    head :not_found unless Rails.env.development?
  end
end
