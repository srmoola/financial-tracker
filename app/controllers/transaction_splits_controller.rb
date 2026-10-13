# Splits a purchase across categories (or undoes the split), then re-renders the page in place.
class TransactionSplitsController < ApplicationController
  before_action :set_transaction

  def update
    if @transaction.split_into(params.expect(parts: [ [ :category, :amount ] ]))
      redirect_to return_path, status: :see_other
    else
      head :unprocessable_content
    end
  end

  def destroy
    @transaction.split_into([])
    redirect_to return_path, status: :see_other
  end

  private
    def set_transaction
      @transaction = Transaction.owned_by(Current.user).find(params[:transaction_id])
    end

    # Back to the same page the split was made from.
    def return_path
      path = params[:return_to].to_s
      path.start_with?("/transactions") ? path : transactions_path
    end
end
