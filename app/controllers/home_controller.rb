# frozen_string_literal: true

# Home: what the Every team uses, the same page for everyone. Every count and name comes
# from the read layer as the viewer (Audience decides who is counted), so Home cannot
# disagree with the Kind page or the agent tools. The response varies by viewer, so it is
# never cached by a shared cache. Search is an optional prop that the page asks for with
# an Inertia partial reload, rate limited per IP.
class HomeController < InertiaController
  allow_unauthenticated_access only: :index

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 120, within: 1.minute, store: RATE_LIMIT_STORE, only: :index, if: -> { params.key?(:q) },
             with: -> { render plain: "Search is busy, try again in a minute.", status: :too_many_requests }

  before_action :vary_by_viewer

  def index
    audience = Audience.new(viewer: Current.user, show: params[:show], person: params[:person])
    rankings = TeamRankings.new(viewer: Current.user, show: params[:show])
    person = PersonPicks.new(viewer: Current.user, show: params[:show]).for(audience.person, team: true) if audience.person
    @page_meta = { description: "Which AI tools and models the Every team uses for each kind of work.", url: "#{LoadoutHost.base_url(request)}/" }

    render inertia: "home/index", props: {
      filters: audience.filters.merge(overall: params[:overall] == "1", q: query),
      people: audience.people,
      notice: audience.notice,
      private_picks: audience.includes_private_picks?,
      empty_reason: rankings.empty_reason,
      launches: ModelLaunches.new(viewer: Current.user, show: params[:show]).list,
      hero: (rankings.hero unless person),
      rows: rankings.rows,
      overall: rankings.overall,
      person:,
      cta: call_to_action,
      all_vibe_checks_url: LoadoutHost::ALL_VIBE_CHECKS_URL,
      search: InertiaRails.optional { Search.new(viewer: Current.user, show: params[:show]).call(params[:q]) }
    }
  end

  private

  def vary_by_viewer
    expires_in 0.seconds, public: false, must_revalidate: true
    response.headers["Vary"] = "Cookie"
  end

  def query
    params[:q].to_s.squish.first(Search::MAX_QUERY_LENGTH).presence
  end

  # Visitors are asked to join, members with nothing ranked to start, and members with picks get none.
  def call_to_action
    if Current.user.nil?
      { label: "Join Every", href: LoadoutHost::JOIN_EVERY_URL }
    elsif Current.user.entries.none?
      { label: "Rank your first tools", href: edit_loadout_path }
    end
  end
end
