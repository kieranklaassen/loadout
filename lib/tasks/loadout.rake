namespace :loadout do
  desc "Render the site-wide share card to public/og-default.png"
  task default_og: :environment do
    path = Rails.public_path.join("og-default.png")
    File.binwrite(path, ProfileCard.site.render)
    puts "Wrote #{path.relative_path_from(Rails.root)}"
  end
end
