# Takes a transaction out of a budget (it stops counting toward it), or puts it back.
class BudgetExclusionsController < ApplicationController
  before_action :set_budget

  def create
    purchase = Transaction.owned_by(Current.user).find(params.expect(:transaction_id))
    @budget.exclusions.find_or_create_by!(purchase:)
    redirect_to budget_path(@budget, back: params[:back].presence), status: :see_other
  end

  def destroy
    @budget.exclusions.find_by!(transaction_id: params[:id]).destroy!
    redirect_to budget_path(@budget, back: params[:back].presence), status: :see_other
  end

  private
    def set_budget
      @budget = Current.user.budgets.find(params[:budget_id])
    end
end
