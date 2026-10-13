# What a user said about a subscription: "confirmed" (a possible one is
# real), "dismissed" (it isn't a subscription) or "added" (by hand, from a
# charge, e.g. a yearly one that hasn't charged twice yet). Can carry a few
# short tags, e.g. to tell apart two subscriptions from the same merchant.
class SubscriptionMark < ApplicationRecord
  KINDS = %w[ confirmed dismissed added ].freeze
  MAX_TAGS = 3
  TAG_MAX_LENGTH = 20

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :merchant, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :period, inclusion: { in: Subscription::PERIODS.keys }
  validate :short_tags

  normalizes :tags, with: ->(tags) { tags.map(&:squish).compact_blank.uniq(&:downcase) }

  # Whether this is about `subscription`: the same merchant and period, and an
  # amount close to one of its charges.
  def matches?(subscription)
    merchant == subscription.merchant && period == subscription.period &&
      subscription.charges.any? { |charge| Subscription.close?(charge.amount, amount) }
  end

  private
    def short_tags
      errors.add(:tags, "can't be more than #{MAX_TAGS}") if tags.size > MAX_TAGS
      errors.add(:tags, "can't be longer than #{TAG_MAX_LENGTH} characters") if tags.any? { |tag| tag.length > TAG_MAX_LENGTH }
    end
end
