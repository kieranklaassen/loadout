namespace :toolbox do
  desc "Render the site-wide share card to public/og-default.png"
  task default_og: :environment do
    path = Rails.public_path.join("og-default.png")
    # The file is committed, so it is quantised to a palette: a quarter of the size, same picture.
    Vips::Image.new_from_buffer(ProfileCard.site.render, "").write_to_file(path.to_s, palette: true, Q: 90)
    puts "Wrote #{path.relative_path_from(Rails.root)}"
  end

  desc "Write config/vibe_checks.yml into team members' dated history (runs on every deploy; safe to run again)"
  task import_vibe_checks: :environment do
    written = VibeChecks::Import.call
    puts written.empty? ? "No Vibe Check member is in Toolbox yet." : written.map { |email, rows| "#{email}: #{rows} #{"row".pluralize(rows)}" }
  end

  desc "Remove a member who left Every (EMAIL=person@every.to): the same deletion as Settings, so their picks, history, suggestions, visibility periods, sessions and agent grants go too"
  task remove_member: :environment do
    email = ENV["EMAIL"].to_s.strip
    user = User.find_by(email_address: email) if email.present?
    abort "No member with the email #{email.inspect}. Usage: EMAIL=person@every.to bin/rails toolbox:remove_member" unless user

    user.destroy!
    puts "Removed #{user.email_address} and everything they had in Toolbox. Tools and models they added stay in the catalog."
  end

  desc "Revoke every agent connection and withdraw the suggestions agents left open; members connect and approve again"
  task revoke_agent_grants: :environment do
    now = Time.current
    grants = withdrawn = nil
    ApplicationRecord.transaction do
      grants = OauthGrant.where(revoked_at: nil).update_all(revoked_at: now, updated_at: now)
      OauthAuthorizationCode.where(used_at: nil).delete_all
      withdrawn = PickSuggestion.open.where.not(oauth_client_id: nil).update_all(status: "withdrawn", resolved_at: now, updated_at: now)
    end
    puts "Revoked #{grants} #{"grant".pluralize(grants)} and withdrew #{withdrawn} open #{"suggestion".pluralize(withdrawn)}."
  end
end
