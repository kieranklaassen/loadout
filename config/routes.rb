Rails.application.routes.draw do
  # Sign in with Every. /auth/every itself is the OmniAuth middleware.
  resource :session, only: %i[new destroy]
  get "auth/every/callback", to: "sessions/every#create"
  draw :dev_login if Rails.env.development?

  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA surface (docs/modules/pwa.md): Rails' built-in controller renders
  # app/views/pwa/*, public and outside the Inertia auth gate. Formats are pinned
  # so a mismatched request 404s at routing instead of raising MissingTemplate
  # (500) in the view layer: /manifest.json is the only manifest URL, and the
  # extension-less /service-worker defaults to js because Rails collapses
  # browser-like Accept headers to html.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, format: true, constraints: { format: "json" }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker,
    defaults: { format: :js }, constraints: { format: "js" }

  # WebMCP tool execution (docs/modules/webmcp.md). The path must match
  # ToolRegistry::ENDPOINT_PATH; names follow the MCP/WebMCP tool-name alphabet.
  post "webmcp/tools/:name" => "webmcp_tools#create", as: :webmcp_tool,
    constraints: { name: /[A-Za-z0-9_.\-]{1,128}/ }, defaults: { format: :json }

  # MCP for agents: Streamable HTTP, OAuth 2.1 bearer tokens.
  match "mcp" => "mcp#handle", via: %i[get post delete], as: :mcp, format: false
  get ".well-known/oauth-protected-resource(/mcp)" => "well_known#protected_resource", as: :oauth_protected_resource, format: false
  get ".well-known/oauth-authorization-server(/mcp)" => "well_known#authorization_server", as: :oauth_authorization_server, format: false
  namespace :oauth do
    post "register" => "registrations#create"
    get "authorize" => "authorizations#new"
    post "authorize" => "authorizations#create"
    post "token" => "tokens#create"
    post "revoke" => "revocations#create"
  end
  resources :agents, only: %i[index destroy]

  # Onboarding, editing, and settings.
  get "welcome", to: "onboarding#show", as: :welcome
  patch "welcome", to: "onboarding#update"
  get "handles/check", to: "handles#check", as: :check_handle
  resource :loadout, only: %i[edit update]
  post "loadout/suggestions/:id/confirm" => "loadouts#confirm", as: :confirm_loadout_suggestion, constraints: { id: /\d+/ }
  delete "loadout/suggestions/:id" => "loadouts#dismiss", as: :loadout_suggestion, constraints: { id: /\d+/ }
  post "loadout/catalog_items" => "loadouts#add_item", as: :loadout_catalog_items
  resource :settings, only: %i[show update destroy] do
    resource :history, only: :show, module: :settings
  end

  # Admin: catalog review and the Flipper dashboard.
  # Non-admins fall through to a 404, not a sign-in redirect.
  admin_only = ->(request) { Session.find_by(id: request.cookie_jar.signed[:session_id])&.user&.admin? }
  constraints(admin_only) do
    mount Flipper::UI.app(Flipper) => "/admin/flipper"
    namespace :admin do
      resources :catalog_items, only: %i[index update destroy] do
        post :merge, on: :member
      end
    end
  end

  root "home#index"
  get "kinds/:slug" => "kinds#show", as: :kind, format: false

  # Profiles live on the root path, so they are drawn last.
  # format: false keeps "/manifest.xml" and friends from reaching a profile.
  handle = Regexp.new(User::Handle::FORMAT.source.delete_prefix("\\A").delete_suffix("\\z"))
  get ":handle/og.png" => "profile_cards#show", as: :profile_card, format: false, constraints: { handle: }
  get ":handle" => "profiles#show", as: :profile, format: false, constraints: { handle: }
end
