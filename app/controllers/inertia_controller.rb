# frozen_string_literal: true

# Base controller for every Inertia-rendered page. Controllers inherit from this
# (never ApplicationController directly), so each new page automatically receives
# the shared props defined here AND the authentication gate — a page cannot ship
# ungated, or without shared context, by omission.
#
# To make a page public, call `allow_unauthenticated_access` (see HomeController,
# SessionsController).
class InertiaController < ApplicationController
  # Authentication gate, default-on. `before_action :require_authentication` runs
  # for every subclass unless it opts out with `allow_unauthenticated_access`.
  include Authentication

  # Onboarding gate: a signed-in member who has not finished onboarding is sent
  # to /welcome from any page. Flows that must work mid-onboarding (sign-in,
  # OAuth consent) opt out with `skip_onboarding_gate`.
  before_action :require_onboarding

  def self.skip_onboarding_gate(**options)
    skip_before_action :require_onboarding, **options
  end

  # The signed-in member, or nil. Pages read identity from here, never refetch it.
  inertia_share current_user: -> { current_user_props if authenticated? }

  # Flash messages, surfaced to every page as a plain hash keyed by type.
  inertia_share flash: -> { flash.to_hash }

  # Active locale, so pages can render language-aware copy without a round trip.
  inertia_share locale: -> { I18n.locale.to_s }

  # Riffrec feedback capture: a boolean gate + the browser-safe config (nil when
  # unconfigured). RiffrecProvider on the client mounts the widget only when
  # enabled. No secret is ever shared — see config/initializers/riffrec.rb.
  inertia_share feedback_capture_enabled: -> { Riffrec.configured? }
  inertia_share riffrec: -> { Riffrec.client_config }

  # WebMCP tool definitions (docs/modules/webmcp.md), signed-in pages only:
  # WebmcpProvider registers them on the browser's model context while this is
  # non-null and unregisters them when it turns null (sign-out).
  inertia_share webmcp: -> { ToolRegistry.manifest if authenticated? }

  # The host printed on pages and cards, from configuration (LoadoutHost).
  inertia_share public_host: -> { LoadoutHost.host }

  private
    def require_onboarding
      return unless request.get? && authenticated?

      redirect_to welcome_path unless Current.user.onboarded?
    end

    def current_user_props
      user = Current.user
      {
        id: user.id,
        name: user.display_name,
        handle: user.handle,
        avatar_url: user.avatar_url,
        every_member: user.every_member?,
        admin: user.admin?,
        visibility: user.visibility,
        email_verified: user.email_verified?,
        onboarded: user.onboarded?
      }
    end
end
