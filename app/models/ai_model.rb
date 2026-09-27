# A model people pick inside a tool: Claude Opus 5.5, GPT-6 Astra, Veo 4.
class AiModel < ApplicationRecord
  include CatalogItem

  # Newer approved models of the same family, newest first.
  def newer_in_family
    return self.class.none if family.blank?

    self.class.approved.where(family:).where.not(id:).select { |model| model.newer_than?(self) }.sort_by(&:recency_key)
  end

  # Release dates decide when both models have one; otherwise catalog order,
  # which lists each family newest first (a lower position is newer).
  def newer_than?(other)
    return false if family.blank? || family != other.family || id == other.id
    return released_on > other.released_on if released_on && other.released_on

    position < other.position
  end

  def recency_key
    [ released_on ? -released_on.jd : 0, position ]
  end
end
