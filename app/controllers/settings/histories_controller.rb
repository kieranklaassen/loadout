# frozen_string_literal: true

# "Download my history": every entry_changes row of the signed-in member, private
# stretches, suggestions and carried-over baselines included, as one JSON file. It
# is the single file response beside /webmcp/tools; it only ever reads Current.user.
class Settings::HistoriesController < InertiaController
  def show
    changes = Current.user.entry_changes.includes(:category, :tool, :ai_model).order(:created_at, :id)

    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Cache-Control"] = "no-store"
    send_data JSON.pretty_generate(exported_at: Time.current.iso8601, changes: changes.map { |change| row(change) }),
      filename: "toolbox-history.json", type: "application/json", disposition: "attachment"
  end

  private

  def row(change)
    {
      at: change.created_at.iso8601,
      action: change.action,
      kind: change.category.slug,
      tool: change.tool.slug,
      model: change.ai_model&.slug,
      rank: change.rank,
      from_rank: change.from_rank,
      context: change.context,
      effort: change.effort,
      source: change.source,
      client_name: change.client_name,
      details: change.details
    }
  end
end
