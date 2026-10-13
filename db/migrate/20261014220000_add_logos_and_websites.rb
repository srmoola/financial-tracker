class AddLogosAndWebsites < ActiveRecord::Migration[8.1]
  def change
    # From Plaid: the merchant's logo and website on each transaction (when it knows them),
    # and the bank's website and logo (a base64 PNG) on each connection.
    add_column :transactions, :logo_url, :string
    add_column :transactions, :website, :string
    add_column :plaid_items, :institution_url, :string
    add_column :plaid_items, :institution_logo, :text
  end
end
