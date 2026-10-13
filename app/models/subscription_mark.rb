# What a user said about a subscription: "confirmed" (a possible one is
# real), "dismissed" (it isn't a subscription) or "added" (by hand, from a
# charge, e.g. a yearly one that hasn't charged twice yet). Can carry a short
# note, e.g. to tell apart two subscriptions from the same merchant.
class SubscriptionMark < ApplicationRecord
  KINDS = %w[ confirmed dismissed added ].freeze
  NOTE_MAX_LENGTH = 40

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :merchant, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :period, inclusion: { in: Subscription::PERIODS.keys }
  validates :note, length: { maximum: NOTE_MAX_LENGTH }

  normalizes :note, with: ->(note) { note.squish.presence }

  # Whether this is about `subscription`: the same merchant and period, and an
  # amount close to one of its charges.
  def matches?(subscription)
    merchant == subscription.merchant && period == subscription.period &&
      subscription.charges.any? { |charge| Subscription.close?(charge.amount, amount) }
  end
end
