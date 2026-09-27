## Residual Review Findings

Source: report-only code review of `cursor/loadout-v1-0cbf` (base `7c80cb1`) on 2026-09-26. Everything else the review raised is fixed on this branch.

- **P2** `app/models/user.rb` (`admin?`), `app/controllers/sessions/every_controller.rb`: admin rights (`ADMIN_EMAILS`) and Every-map access (`@every.to`) trust the email Every's UserInfo returns. Sign-in only refuses an explicit `email_verified: false`. Confirm with Every that UserInfo emails are always verified; otherwise key admins on `every_user_id` or the `admin` column only. Needs a product decision.
- **P3** `app/models/profile_card.rb` (`avatar`): R21 asks for the member's avatar on the share card; the card draws initials. Rendering the remote avatar needs a fetch with size and timeout limits. Deferred.
- **P3** Success criteria ask for system tests (onboarding, visibility, MCP OAuth, map). Coverage today is controller, integration (including the full PKCE flow over `/mcp`), and Vitest; there is no `test/system` yet. Deferred.
