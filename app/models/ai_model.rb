# A model people pick inside a tool: Claude Opus 5.5, GPT-6 Astra, Veo 4.
class AiModel < ApplicationRecord
  include CatalogItem

  # Newer approved models of the same family, newest first. Within a family the
  # catalog lists models newest first, so a lower position is newer.
  def newer_in_family
    return self.class.none if family.blank?

    self.class.approved.where(family:).where("position < ?", position).order(:position)
  end
end
