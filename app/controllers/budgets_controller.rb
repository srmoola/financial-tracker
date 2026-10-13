# Spending limits for a week or a statement month, over chosen categories and merchants.
class BudgetsController < ApplicationController
  MERCHANT_CHOICES = 60

  HISTORY_PERIODS = 12

  before_action :set_budget, only: %i[ show edit update destroy ]
  helper_method :merchant_choices

  def index
    @budgets = Current.user.budgets.order(:created_at).map { |budget| [ budget, budget.status ] }
  end

  def show
    @status = @budget.status
    @history = @budget.history(HISTORY_PERIODS)
  end

  def new
    @budget = Current.user.budgets.new(period: "monthly")
  end

  def create
    @budget = Current.user.budgets.new(budget_params)
    if @budget.save
      @budget.reset_alerts!
      redirect_to budgets_path, notice: "Created #{@budget.name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @budget.update(budget_params)
      @budget.reset_alerts!
      redirect_to budgets_path, notice: "Saved #{@budget.name}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @budget.destroy!
    redirect_to budgets_path, notice: "Deleted #{@budget.name}.", status: :see_other
  end

  private
    def set_budget
      @budget = Current.user.budgets.find(params[:id])
    end

    # The merchants to choose from: the ones you've spent most with in the last
    # 6 months (leaving out masked statement descriptions), plus any already picked.
    def merchant_choices
      @merchant_choices ||= @budget.merchants | Transaction.owned_by(Current.user)
        .where(date: 6.months.ago.to_date.., amount: 0..)
        .where("#{Transaction::MERCHANT_SQL} IS NOT NULL AND #{Transaction::MERCHANT_SQL} NOT LIKE ?", "%**%")
        .group(Arel.sql(Transaction::MERCHANT_SQL)).order(Arel.sql("SUM(transactions.amount) DESC"))
        .limit(MERCHANT_CHOICES).pluck(Arel.sql(Transaction::MERCHANT_SQL))
    end

    def budget_params
      params.expect(budget: [ :name, :amount, :period, :rollover, categories: [], merchants: [] ])
    end
end
