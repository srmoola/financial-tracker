class AddStatementDates < ActiveRecord::Migration[8.1]
  def change
    # From Plaid Liabilities: when each credit card's last statement was issued.
    add_column :accounts, :last_statement_issue_date, :date
    # Whether a connection can provide statement dates: "available", "needs_consent" or "unsupported".
    add_column :plaid_items, :statement_dates_status, :string
  end
end
