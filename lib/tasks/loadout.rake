namespace :loadout do
  desc "Render the site-wide share card to public/og-default.png"
  task default_og: :environment do
    path = Rails.public_path.join("og-default.png")
    File.binwrite(path, ProfileCard.site.render)
    puts "Wrote #{path.relative_path_from(Rails.root)}"
  end

  desc "Remove a member who left Every (EMAIL=person@every.to): the same deletion as Settings, so their picks, history, suggestions, visibility periods, sessions and agent grants go too"
  task remove_member: :environment do
    email = ENV["EMAIL"].to_s.strip
    user = User.find_by(email_address: email) if email.present?
    abort "No member with the email #{email.inspect}. Usage: EMAIL=person@every.to bin/rails loadout:remove_member" unless user

    user.destroy!
    puts "Removed #{user.email_address} and everything they had in Loadout. Tools and models they added stay in the catalog."
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
