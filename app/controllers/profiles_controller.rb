# frozen_string_literal: true

# A member's loadout at /:handle. Public profiles are open to anyone; private
# ones answer 404 to everyone but their owner, exactly like an unknown handle.
class ProfilesController < InertiaController
  include ProfileLookup

  allow_unauthenticated_access only: :show

  RECENT_CHANGES = 10

  def show
    user = find_profile!
    presenter = Loadouts::Presenter.new(user)
    @page_meta = page_meta_for(user, presenter)

    render inertia: "profiles/show", props: {
      profile: profile_props(user),
      categories: presenter.categories,
      recent_changes: presenter.recent_changes(limit: RECENT_CHANGES),
      is_owner: owner?(user)
    }
  end

  private

  def profile_props(user)
    {
      handle: user.handle,
      name: user.display_name,
      avatar_url: user.avatar_url,
      bio: user.bio,
      every_member: user.every_member?,
      public: user.public?,
      url: "#{public_base_url}/#{user.handle}",
      display_url: "#{public_host}/#{user.handle}"
    }
  end

  def page_meta_for(user, presenter)
    name = user.display_name
    meta = {
      title: "#{name}'s AI loadout",
      description: description_for(name, presenter.top_picks),
      url: "#{public_base_url}/#{user.handle}",
      type: "profile",
      image_alt: "#{name}'s AI loadout on Loadout"
    }
    return meta.merge(noindex: true) unless user.public?

    meta.merge(image: "#{public_base_url}/#{user.handle}/og.png?v=#{user.loadout_updated_at.to_i}")
  end

  def description_for(name, top_picks)
    picks = top_picks.map do |category|
      entry = category[:entries].first
      subject = [ entry[:tool][:name], entry[:model]&.dig(:name) ].compact.join(" with ")
      "#{subject} for #{category[:name].downcase}"
    end
    return "#{name} hasn't picked their AI tools yet." if picks.empty?

    "#{name}'s go-to AI: #{picks.to_sentence}.".truncate(200, separator: " ")
  end
end
