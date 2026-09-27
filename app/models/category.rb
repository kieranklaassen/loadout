# A kind of work people use AI for: coding, knowledge work, video, speech to text.
class Category < ApplicationRecord
  has_many :entries, dependent: :restrict_with_exception

  validates :slug, :name, presence: true
  validates :slug, uniqueness: true

  default_scope { order(:position, :name) }

  def self.resolve(value)
    return value if value.is_a?(Category)

    key = value.to_s.strip.downcase
    find_by(slug: key) || find_by(slug: key.parameterize) || where("lower(name) = ?", key).first
  end

  def to_prop
    { slug:, name:, blurb: blurb.to_s }
  end
end
