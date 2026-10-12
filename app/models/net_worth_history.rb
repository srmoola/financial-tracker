# Net worth per day, built from per-account balance snapshots (anything with
# date, balance, account_type and subtype), using the same rules as NetWorthBreakdown.
# Each point also keeps that day's total per category and the credit card debt.
class NetWorthHistory
  Point = Data.define(:date, :net_worth, :categories, :debts)

  RANGES = { "1m" => 1.month, "3m" => 3.months, "6m" => 6.months, "1y" => 1.year }.freeze
  DEFAULT_RANGE = "6m"

  attr_reader :points

  def self.range_start(range, today: Date.current) = today - RANGES.fetch(range)

  def initialize(snapshots)
    @points = snapshots.group_by(&:date).sort.map do |date, snapshots_that_day|
      breakdown = NetWorthBreakdown.new(snapshots_that_day)
      totals = breakdown.groups.to_h { |group| [ group.key, group.total ] }

      Point.new(
        date:,
        net_worth: breakdown.net_worth,
        categories: NetWorthBreakdown::GROUPS.keys.index_with { |key| totals.fetch(key, 0) },
        debts: breakdown.debts_total
      )
    end
  end

  def change = points.last.net_worth - points.first.net_worth
  def change_percent = change / points.first.net_worth * 100
end
