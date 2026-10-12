# Groups accounts into the dashboard's net worth categories, using Plaid's
# account type and subtype. Works with anything that responds to account_type,
# subtype and balance (sample data today, Account records later).
class NetWorthBreakdown
  Group = Data.define(:key, :label, :accounts) do
    def total = accounts.sum(&:balance)
  end

  GROUPS = { checking: "Checking", savings: "Savings", investments: "Investments" }.freeze

  attr_reader :groups, :debts

  def initialize(accounts)
    by_group = accounts.group_by { |account| self.class.group_for(account) }
    @groups = GROUPS.filter_map do |key, label|
      Group.new(key:, label:, accounts: by_group[key]) if by_group[key]
    end
    @debts = by_group.fetch(:debts, [])
  end

  def assets_total = groups.sum(&:total)
  def debts_total = debts.sum(&:balance)
  def net_worth = assets_total - debts_total
  def asset_account_count = groups.sum { |group| group.accounts.size }

  # The group an account belongs to (:checking, :savings, :investments or :debts).
  # Raises for account types we don't handle yet (e.g. loans), rather than
  # silently leaving them out of net worth.
  def self.group_for(account)
    case [ account.account_type, account.subtype ]
    in [ "depository", "checking" ] then :checking
    in [ "depository", _ ] then :savings
    in [ "investment", _ ] then :investments
    in [ "credit", _ ] then :debts
    end
  end
end
