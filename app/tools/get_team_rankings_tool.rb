# frozen_string_literal: true

# What the site's Home and Kind pages show, for the acting member: the same query objects
# (TeamRankings, Audience) with the member as the viewer, so an agent cannot see anyone or
# anything the member could not see on the site.
class GetTeamRankingsTool < ApplicationTool
  tool_name "get_team_rankings"
  description <<~TEXT.squish
    Returns what the team uses, as the signed-in member sees it on the site. Without `category`
    it returns the Overall top tools and models and, for each kind of work, the most used tool
    and model. With `category` (a slug from list_categories) it returns that kind in detail: every
    tool and model with who ranked it 1st, 2nd and 3rd, the setups (tool, model, context size and
    effort) people share, and links to Vibe Check takes, which need a sign-in and which you
    cannot read. `count` is { n, of }: n of the `of` people counted use it. Counts are people,
    not scores. `audience` picks who is counted: `team` (Every team members who share with the
    member, the default) or `others` (everyone else who shares with the member); `subscribers`
    is not available yet. Only people who chose to share with the member are counted, plus the
    member's own picks; when nobody is, `people` is 0 and `reason` is nobody_shared. #{DATA_NOTICE}
  TEXT
  input_schema(
    properties: {
      audience: { type: "string", enum: Audience::SHOWS, description: "Who is counted (default team)." },
      category: { type: "string", maxLength: 60, description: "A category slug from list_categories, for one kind in detail." }
    },
    required: [],
    additionalProperties: false
  )
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    show = arguments.fetch(:audience, Audience::DEFAULT_SHOW)
    raise Error, "not_available_yet: Every subscribers have no data yet. Use \"team\" or \"others\"." if show == "subscribers" && !Audience::SUBSCRIBERS_AVAILABLE

    rankings = TeamRankings.new(viewer: user, show:)
    category = find_category
    header(rankings).merge(category ? kind(rankings, category) : overview(rankings))
  end

  private
    def header(rankings)
      {
        audience: rankings.audience.show,
        people: rankings.people_count,
        includes_your_private_picks: rankings.audience.includes_private_picks?,
        reason: rankings.empty_reason
      }.compact
    end

    def overview(rankings)
      {
        overall: rankings.overall.transform_values { |standings| standings.map { |entry| standing(entry) } },
        kinds: rankings.rows.map { |row| row_prop(row) }
      }
    end

    def row_prop(row)
      row[:category].slice(:slug, :name).merge(
        top_tool: leader(row[:top_tool]), top_model: leader(row[:top_model]),
        ranked: row[:ranked], last_update_at: row[:last_update_at], stale: row[:stale]
      )
    end

    def kind(rankings, category)
      detail = rankings.kind(category)
      {
        kind: detail[:category].slice(:slug, :name),
        ranked: detail[:ranked],
        tools: detail[:tools].map { |listing| ranked_listing(listing) },
        models: detail[:models].map { |listing| ranked_listing(listing) },
        setups: detail[:setups].map { |setup| setup.merge(tool: item_prop(setup[:tool]), model: item_prop(setup[:model])) },
        takes: detail[:takes].map { |take| { model: item_prop(take[:model]), vibe_check_url: take[:url] } },
        last_update_at: detail[:last_update_at]
      }
    end

    def ranked_listing(listing)
      standing(listing).merge(ranked_by: listing[:by_rank].transform_values { |people| people.map { |person| person_prop(person) } })
    end

    def standing(entry)
      { item: item_prop(entry[:item]), count: entry[:count] }
    end

    def leader(entry)
      entry && standing(entry).merge(runner_up: entry[:runner_up]&.then { |runner_up| standing(runner_up) })
    end

    def item_prop(item)
      item&.slice(:slug, :name)
    end

    def person_prop(person)
      { handle: person[:handle], name: clean(person[:name]) }
    end
end
