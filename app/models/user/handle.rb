# The profile link a member claims: loadout.every.to/<handle>. Handles share the
# root path with app routes, so anything a route might ever need is reserved.
module User::Handle
  extend ActiveSupport::Concern

  FORMAT = /\A[a-z0-9](?:[a-z0-9-]{0,28}[a-z0-9])?\z/
  RESERVED = %w[
    about account admin agents api app apps assets auth blog cable categories catalog connect
    dev docs every explore faq help home icon login logout loadout manifest map maps mcp me
    new oauth og onboarding privacy profile profiles public rails search service-worker session
    sessions settings signin signout signup static support terms tools up users webmcp welcome
    well-known www
  ].freeze

  included do
    normalizes :handle, with: ->(value) { value.to_s.strip.downcase.delete_prefix("@").presence }

    validates :handle, uniqueness: { case_sensitive: false }, allow_nil: true
    validates :handle, format: { with: FORMAT, message: "can use lowercase letters, numbers, and dashes (2 to 30 characters)" },
      length: { minimum: 2, maximum: 30 }, allow_nil: true
    validate :handle_not_reserved
  end

  class_methods do
    def handle_available?(candidate, except: nil)
      user = new(handle: candidate)
      user.id = except&.id
      user.validate
      user.errors[:handle].empty? && !where(handle: user.handle).where.not(id: except&.id).exists?
    end

    # { handle:, available:, message: } for the live check on the claim step and
    # in settings. A member's own current handle counts as available to them.
    def handle_availability(candidate, except: nil)
      probe = new(handle: candidate)
      handle = probe.handle.to_s
      return { handle:, available: false, message: "Pick a handle." } if handle.blank?

      probe.validate
      problem = probe.errors.objects.find { |error| error.attribute == :handle && error.type != :taken }
      if problem
        message = problem.type == :reserved ? "loadout.every.to/#{handle} is reserved." : "Use 2 to 30 lowercase letters, numbers, and dashes."
        return { handle:, available: false, message: }
      end

      if where(handle:).where.not(id: except&.id).exists?
        { handle:, available: false, message: "loadout.every.to/#{handle} is taken." }
      else
        { handle:, available: true, message: "loadout.every.to/#{handle} is yours." }
      end
    end

    # A free handle derived from a name or email, for prefilling the claim step.
    def suggest_handle(from:, except: nil)
      base = from.to_s.split("@").first.to_s.unicode_normalize(:nfkd).downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")[0, 24]
      base = "member" if base.length < 2
      ([ base ] + (2..50).map { |n| "#{base}-#{n}" }).find { |candidate| handle_available?(candidate, except:) }
    end
  end

  private

  def handle_not_reserved
    errors.add(:handle, :reserved, message: "is reserved") if handle.present? && RESERVED.include?(handle)
  end
end
