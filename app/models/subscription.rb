# A subscription found in a user's credit card purchases: the same merchant
# charging about the same amount every month (26-35 days apart) or every year
# (350-380 days apart). Worked out from the transactions each time, so new
# ones show up as their charges come in.
#
# - Two charges of exactly the same amount make a *possible* subscription,
#   for the user to confirm; three or more make it *active*. A charge counts
#   toward a subscription when it's within 5% of its last one, or, for a price
#   change, within 25% and on schedule after two charges at the old price.
# - It has *ended* once its next charge is overdue by the grace period.
# - The user's SubscriptionMarks confirm, dismiss or add subscriptions by hand,
#   and hold their tags.
class Subscription
  PERIODS = {
    "monthly" => { label: "Monthly", gaps: 26..35, every: 1.month, grace: 10.days },
    "yearly" => { label: "Yearly", gaps: 350..380, every: 1.year, grace: 30.days }
  }.freeze
  HISTORY = 13.months
  NEW_FOR = 7.days
  PRICE_CHANGE = 0.25 # the most a charge on schedule can differ and still be the same subscription

  Charge = Data.define(:id, :account_id, :date, :amount, :arrived_at)

  attr_reader :merchant, :period, :charges, :status, :account, :mark

  # Every subscription for `user` (active, possible and ended), biggest monthly cost first.
  def self.for(user, today: Date.current)
    marks = user.subscription_marks.to_a
    accounts = user.accounts.credit_cards.index_by(&:id)
    charges = Transaction.where(account: accounts.values, date: (today - HISTORY)..).where("transactions.amount > 0")
      .where("#{Transaction::EFFECTIVE_CATEGORY_SQL} IS NULL OR #{Transaction::EFFECTIVE_CATEGORY_SQL} NOT IN (?)", Budget::NOT_SPENDING)
      .order(:date).pluck(:id, :account_id, :merchant_name, :description, :date, :amount, :created_at)
      .filter_map { |id, account_id, merchant_name, description, date, amount, created_at|
        merchant = Transaction.merchant_key(merchant_name, description)
        [ merchant, Charge.new(id:, account_id:, date:, amount:, arrived_at: created_at) ] if merchant
      }.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

    found = charges.flat_map { |merchant, merchant_charges| groups(merchant_charges).filter_map { |group| detect(merchant, group, marks, accounts, today) } }
    added = marks.select { |mark| mark.kind == "added" && found.none? { |subscription| mark.matches?(subscription) } }.map do |mark|
      same = charges.fetch(mark.merchant, []).select { |charge| close?(charge.amount, mark.amount) }
      same = [ Charge.new(id: nil, account_id: nil, date: mark.charged_on, amount: mark.amount, arrived_at: mark.created_at) ] if same.empty?
      new(mark.merchant, mark.period, same, accounts, today, confirmed: true, added: true, mark:)
    end

    (found + added).sort_by { |subscription| -subscription.monthly_cost }
  end

  # Within $1 or 5% of each other: the same subscription after a small price change.
  def self.close?(amount, other) = (amount - other).abs <= [ 1, other * 0.05 ].max

  # A merchant's charges, grouped by amount: each joins the group whose latest
  # charge is close to it, or one it follows on schedule after a price change.
  def self.groups(charges)
    charges.each_with_object([]) do |charge, groups|
      group = groups.find { |candidate| close?(charge.amount, candidate.last.amount) } ||
        groups.find { |candidate| price_change?(candidate, charge) }
      group ? group << charge : groups << [ charge ]
    end
  end

  # A new price for an established subscription (two charges at the old price),
  # rather than, say, a restaurant visited about monthly at different prices.
  def self.price_change?(group, charge)
    last = group.last
    gap = (charge.date - last.date).to_i
    group.size >= 2 && close?(last.amount, group[-2].amount) &&
      PERIODS.values.any? { |rules| rules[:gaps].cover?(gap) } && (charge.amount - last.amount).abs <= last.amount * PRICE_CHANGE
  end

  def self.detect(merchant, charges, marks, accounts, today)
    return if charges.size < 2

    gaps = charges.each_cons(2).map { |earlier, later| (later.date - earlier.date).to_i }
    period = PERIODS.find { |_, rules| gaps.all? { |gap| rules[:gaps].cover?(gap) } }&.first
    return unless period
    return if charges.size == 2 && charges.map(&:amount).uniq.size > 1 # two charges must match to the cent

    subscription = new(merchant, period, charges, accounts, today)
    mark = marks.find { |candidate| candidate.matches?(subscription) }
    return if mark&.kind == "dismissed"

    mark ? new(merchant, period, charges, accounts, today, confirmed: true, added: mark.kind == "added", mark:) : subscription
  end
  private_class_method :groups, :price_change?, :detect

  # `added`: the user added it by hand (so it's never "new" to them).
  # `mark`: the user's SubscriptionMark for it, if any.
  def initialize(merchant, period, charges, accounts, today, confirmed: false, added: false, mark: nil)
    @merchant = merchant
    @mark = mark
    @period = period
    @charges = charges
    @account = accounts[charges.last.account_id]
    @added = added
    @status =
      if today > next_on + PERIODS.fetch(period)[:grace] then :ended
      elsif confirmed || charges.size >= 3 then :active
      else :possible
      end
  end

  def amount = charges.last.amount
  # What it cost before the latest charge, when the price changed.
  def previous_amount = (charges[-2].amount if charges.size >= 2 && charges[-2].amount != amount)
  def last_on = charges.last.date
  def next_on = last_on + PERIODS.fetch(period)[:every]
  def monthly_cost = period == "monthly" ? amount : amount / 12
  def yearly_cost = period == "monthly" ? amount * 12 : amount
  def label = PERIODS.fetch(period)[:label]
  def tags = mark&.tags || []

  # Found (its second charge came in) during `times`; added-by-hand ones aren't news.
  def found_during?(times) = status != :ended && !@added && charges.size >= 2 && times.cover?(charges[1].arrived_at)
  # Found lately, unless the user removed its "New" chip.
  def new?(now: Time.current) = !mark&.seen? && found_during?((now - NEW_FOR)..now)

  # Identifies it for SubscriptionMarks.
  def key = { merchant:, amount:, period: }

  # Identifies it on the page.
  def dom_id = "subscription_#{Digest::SHA1.hexdigest([ merchant, amount.to_s, period ].join("|")).first(12)}"
end
