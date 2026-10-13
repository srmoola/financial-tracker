# The subscriptions found in the user's card purchases (see Subscription),
# and adding, confirming, dismissing or tagging them.
class SubscriptionsController < ApplicationController
  ADD_FROM_DAYS = 90

  def index
    subscriptions = Subscription.for(Current.user)
    @active = subscriptions.select { |subscription| subscription.status == :active }
    @possible = subscriptions.select { |subscription| subscription.status == :possible }
    @ended = subscriptions.select { |subscription| subscription.status == :ended }.sort_by(&:last_on).reverse
  end

  # Pick a recent charge to add as a subscription (e.g. a yearly one that hasn't charged twice yet).
  def new
    @charges = Transaction.where(account: Current.user.accounts.credit_cards, date: ADD_FROM_DAYS.days.ago.to_date..)
      .where("transactions.amount > 0").order(date: :desc).to_a
      .uniq { |charge| [ Transaction.merchant_key(charge.merchant_name, charge.description), charge.amount ] }
      .select { |charge| Transaction.merchant_key(charge.merchant_name, charge.description) }
  end

  def create
    charge = Transaction.owned_by(Current.user).find(params.expect(:transaction_id))
    merchant = Transaction.merchant_key(charge.merchant_name, charge.description)
    Current.user.subscription_marks.create!(kind: "added", merchant:, amount: charge.amount, period: params.expect(:period), charged_on: charge.date)
    redirect_to subscriptions_path, notice: "Added #{merchant}."
  end

  # "Yes, it's a subscription" on a possible one.
  def confirm
    mark = mark!("confirmed")
    redirect_to subscriptions_path, notice: "Added #{mark.merchant} to your subscriptions.", status: :see_other
  end

  # "Not a subscription": hidden from now on, replacing anything said before about it.
  def dismiss
    mark = mark!("dismissed")
    redirect_to subscriptions_path, notice: "#{mark.merchant} won't show up as a subscription.", status: :see_other
  end

  # Sets a subscription's tags (all of them, so removing one sends the rest).
  # One without a mark yet gets a "confirmed" one to hold them: tagging it says
  # it's a subscription. After adding one, the field to add another stays open.
  def tags
    key = params.expect(subscription: [ :merchant, :amount, :period ])
    subscription = Subscription.for(Current.user).find { |candidate| candidate.key == { merchant: key[:merchant], amount: BigDecimal(key[:amount]), period: key[:period] } } or
      raise ActiveRecord::RecordNotFound
    mark = subscription.mark || Current.user.subscription_marks.new(kind: "confirmed", **subscription.key)
    tags_before = mark.tags.size

    if mark.update(tags: Array(params[:tags]).map(&:to_s))
      adding = mark.tags.size > tags_before && mark.tags.size < SubscriptionMark::MAX_TAGS
      redirect_to subscriptions_path(tagging: (subscription.dom_id if adding)), status: :see_other
    else
      head :unprocessable_content
    end
  end

  private
    def mark!(kind)
      key = params.expect(subscription: [ :merchant, :amount, :period ])
      marks = Current.user.subscription_marks
      marks.where(merchant: key[:merchant], period: key[:period]).select { |mark| Subscription.close?(mark.amount, BigDecimal(key[:amount])) }.each(&:destroy!)
      marks.create!(kind:, **key)
    end
end
