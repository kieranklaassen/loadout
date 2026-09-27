# frozen_string_literal: true

# One person's page at /:handle, read as the viewer: PersonPicks decides what may be shown,
# so a page the viewer may not open is the same not-found page as a handle nobody claimed
# (equal props, so nothing tells the two apart). Both answer with the viewer's cookie in
# mind, so no shared cache may keep either.
class ProfilesController < InertiaController
  include ProfileLookup

  allow_unauthenticated_access only: :show

  before_action :vary_by_viewer
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    user = find_profile!
    people = PersonPicks.new(viewer: Current.user)
    picks = people.for(user)
    you = comparison_picks(people, user)
    @page_meta = page_meta_for(user, picks)

    render inertia: "profiles/show", props: picks.merge(bio: user.bio, viewer_can_compare: you.any?, you:, copy_url: profile_url(user))
  end

  private

  def vary_by_viewer
    expires_in 0.seconds, public: false, must_revalidate: true
    response.headers["Vary"] = "Cookie"
  end

  # A visitor who signs in lands back here, so a team member who followed a team link
  # signed out gets to the page they were sent to.
  def not_found
    remember_return_location unless authenticated?
    render inertia: "errors/not_found", status: :not_found
  end

  # The viewer's own picks by kind (only the kinds they ranked), for Compare with mine.
  # None for a visitor, a member with nothing ranked, or on their own page.
  def comparison_picks(people, user)
    viewer = Current.user
    return {} if viewer.nil? || viewer == user

    people.for(viewer)[:kinds].reject { |kind| kind[:picks].empty? }.to_h { |kind| [ kind[:category][:slug], kind[:picks] ] }
  end

  def profile_url(user)
    "#{public_base_url}/#{user.handle}"
  end

  # Only a page a visitor may open (anyone with the link) is indexed and gets a share card.
  def page_meta_for(user, picks)
    name = picks[:person][:name]
    meta = {
      title: "#{name}'s loadout",
      description: description_for(name, picks[:kinds]),
      url: profile_url(user),
      type: "profile"
    }
    return meta.merge(noindex: true) unless user.visible_to?(nil)
    return meta unless ProfileCard.new(user).picks?

    meta.merge(image: "#{profile_url(user)}/og.png?v=#{user.loadout_updated_at.to_i}", image_alt: "#{name}'s loadout on Loadout")
  end

  # Their first pick in up to three kinds: "Cursor with Claude Opus 5.5 for coding and Claude for writing".
  def description_for(name, kinds)
    firsts = kinds.filter_map do |kind|
      pick = kind[:picks].first or next
      subject = [ pick[:tool][:name], pick.dig(:model, :name) ].compact.join(" with ")
      "#{subject} for #{kind[:category][:name].downcase}"
    end
    return "#{name} hasn't ranked their AI tools yet." if firsts.empty?

    "#{name}'s top picks: #{firsts.first(3).to_sentence}.".truncate(200, separator: " ")
  end
end
