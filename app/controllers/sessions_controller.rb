class SessionsController < InertiaController
  allow_unauthenticated_access only: %i[ new create ]

  # Rate-limit sign-in attempts against an explicitly-owned in-memory store.
  # NOT Rails.cache: under class-body evaluation timing the app cache can still
  # be the null store, which would make this a silent no-op. An owned MemoryStore
  # is always a real, counting store.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 10, within: 3.minutes, only: :create, store: RATE_LIMIT_STORE,
             with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again later." }

  def new
    render inertia: "auth/sign_in"
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password)))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      # Byte-identical message for both unknown email and wrong password — no
      # account-enumeration oracle. authenticate_by already runs a dummy bcrypt
      # for unknown emails, so timing does not leak either.
      redirect_to new_session_path, alert: "Invalid email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
