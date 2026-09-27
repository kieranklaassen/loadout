# frozen_string_literal: true

# One kind of work at /kinds/:slug: who ranks which tools and models, how they set them up,
# and what the team used before. Like Home it is read as the viewer from the read layer
# (Audience decides who is counted and named), so it cannot disagree with Home or the agent
# tools, and the response is never cached by a shared cache.
class KindsController < InertiaController
  allow_unauthenticated_access only: :show

  before_action :vary_by_viewer

  def show
    category = Category.find_by!(slug: params[:slug])
    rankings = TeamRankings.new(viewer: Current.user, show: params[:show])
    kind = rankings.kind(category)
    eras = NumberOneHistory.new(viewer: Current.user, show: params[:show]).eras(category)
    @page_meta = {
      title: "#{category.name} on Loadout",
      description: "Which AI tools and models the Every team uses for #{category.name.downcase}.",
      url: "#{LoadoutHost.base_url(request)}/kinds/#{category.slug}"
    }

    render inertia: "kinds/show", props: {
      filters: { show: rankings.audience.show },
      notice: rankings.audience.notice,
      **kind.slice(:category, :ranked, :tools, :models, :setups, :takes, :last_update_at),
      eras: (eras if eras.size >= 2),
      cta: call_to_action(category)
    }
  end

  private

  def vary_by_viewer
    expires_in 0.seconds, public: false, must_revalidate: true
    response.headers["Vary"] = "Cookie"
  end

  # Only ever selects the kind in the editor; visitors come back to it after signing in.
  def call_to_action(category)
    name = category.name.downcase
    label =
      if Current.user.nil? then "Sign in to rank #{name}"
      elsif Current.user.entries.exists?(category:) then "Edit your #{name} picks"
      else "Rank your #{name} picks"
      end
    { label:, href: edit_loadout_path(kind: category.slug) }
  end
end
