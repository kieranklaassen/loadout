# frozen_string_literal: true

# The latest model launches on Home: models with a release date and a valid Vibe Check
# link, newest first, at most three, each with how many of the audience use it.
#
#   ModelLaunches.new(viewer: Current.user, show: params[:show]).list
#
# Arguments
#   viewer:  a User, or nil for a visitor.
#   show:    "team" (default) or "others", as for Audience.
#
# Public methods
#   list                 [{ model: Mark item, released_on: "2026-09-22", vibe_check_url:, newest:,
#                           adoption: { n:, of: }, mostly_in: Mark item or nil }]
#                        adoption is N of M across all kinds, from TeamRankings.item_counts; mostly_in
#                        is the tool most people use the model in, only from two people. When nobody has
#                        shared, adoption is { n: 0, of: 0 }: show the empty state, not "0 of 0".
#   ModelLaunches.models  every launched model with an allowed link, newest first (the one listing rule)
class ModelLaunches
  LIMIT = 3

  attr_reader :rankings

  def self.models
    AiModel.launched.order(released_on: :desc, position: :asc).select(&:vibe_check_link)
  end

  def initialize(viewer:, show: nil)
    @rankings = TeamRankings.new(viewer:, show:)
  end

  def list
    self.class.models.first(LIMIT).each_with_index.map do |model, index|
      {
        model: model.to_prop,
        released_on: model.released_on.iso8601,
        vibe_check_url: model.vibe_check_link,
        newest: index.zero?,
        adoption: rankings.count_of(:model, model.id),
        mostly_in: rankings.mostly_in(model)
      }
    end
  end
end
