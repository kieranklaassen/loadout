# frozen_string_literal: true

# The front door. Signed-out visitors get the landing page; members go straight
# to their profile (or finish onboarding first).
class HomeController < InertiaController
  allow_unauthenticated_access only: :index

  FEATURED_LIMIT = 6

  def index
    if authenticated?
      return redirect_to "/welcome" unless Current.user.onboarded?
      return redirect_to "/#{Current.user.handle}"
    end

    render inertia: "home/index", props: {
      stats: { members: User.where.not(onboarded_at: nil).count, picks: Entry.count, tools: Tool.approved.count },
      featured: featured_profiles
    }
  end

  private

  def featured_profiles
    User.publicly_visible.where.not(loadout_updated_at: nil).order(loadout_updated_at: :desc).limit(FEATURED_LIMIT).map do |user|
      picks = Loadouts::Presenter.new(user).top_picks.first(4).map do |category|
        entry = category[:entries].first
        { category: category[:name], tool: entry[:tool], model: entry[:model] }
      end
      { handle: user.handle, name: user.display_name, avatar_url: user.avatar_url, picks: }
    end
  end
end
