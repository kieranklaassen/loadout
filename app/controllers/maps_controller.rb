# frozen_string_literal: true

# The Every map. Every members see what colleagues use; everyone else gets an
# explainer, unless the public_map flag is on for them. Reachable signed out so
# the explainer can render.
class MapsController < InertiaController
  allow_unauthenticated_access

  def index
    return render_explainer unless map_visible?

    stats = MapStats.new(viewer: Current.user)
    render inertia: "map/index", props: {
      summary: stats.summary,
      categories: stats.categories,
      discovery: stats.discovery
    }
  end

  def show
    category = Category.find_by!(slug: params[:category])
    return render_explainer unless map_visible?

    stats = MapStats.new(viewer: Current.user)
    render inertia: "map/show", props: {
      panel: stats.category(category),
      people: stats.people(category),
      categories: Category.all.map(&:to_prop)
    }
  end

  private

  def map_visible?
    return true if authenticated? && Current.user.every_member?

    Flipper.enabled?(:public_map, Current.user)
  end

  def render_explainer
    render inertia: "map/explainer", props: { signed_in: authenticated?.present? }
  end
end
