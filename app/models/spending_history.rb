# Credit card spending over time, in the same categories as the spending donut.
# Ranges under 6 months show how spending builds up day by day; longer ones
# show the total for each statement period, using each card's own statement dates.
class SpendingHistory
  # `top_purchases`: the point's largest purchases (that day's, or that statement
  # period's), biggest first, out of `purchase_count`.
  Point = Data.define(:date, :label, :total, :by_category, :purchase_count, :top_purchases)
  TOP_PURCHASES = 5
  DAILY_UNDER_PERIODS = 6 # statement periods back; 6M and longer go by period

  attr_reader :points

  # `purchases`: the purchases (positive amounts) to chart, already limited to
  # the range. `category_keys`: the donut's named categories; anything else is
  # counted as :other. `periods_back`: statement periods before the current
  # one (nil for all time).
  def initialize(purchases, cards:, category_keys:, periods_back:, today: Date.current)
    @cards = cards
    @today = today
    @group = ->(category) { category_keys.include?(category) ? category : :other }
    rows = purchases.with_parts.pluck(:id, :account_id, :date, Arel.sql(Transaction::PART_CATEGORY_SQL), Arel.sql(Transaction::PART_AMOUNT_SQL))

    @daily = periods_back.present? && periods_back < DAILY_UNDER_PERIODS
    @points = with_top_purchases(@daily ? daily_points(rows, periods_back) : period_points(rows, periods_back || periods_since(rows)))
  end

  # True when points are days with running totals, not statement periods.
  def daily? = @daily
  def empty? = points.none? { |point| point.total.positive? }

  private
    # A running total per category for each day since the range's first statement
    # period began, with that day's purchases.
    def daily_points(rows, periods_back)
      by_day = rows.group_by { |_, _, date, _, _| date }

      running = Hash.new(0)
      (@cards.map { |card| card.statement_period_start(periods_back, today: @today) }.min..@today).map do |day|
        day_rows = by_day.fetch(day, [])
        day_rows.each { |_, _, _, category, amount| running[@group.(category)] += amount }
        [ { date: day, label: day.strftime("%b %-d, %Y"), total: running.values.sum, by_category: running.dup }, day_rows ]
      end
    end

    # Totals per category for each statement period, oldest first, with that
    # period's purchases. Each transaction lands in its own card's period; labels
    # use the first card's dates.
    def period_points(rows, periods)
      cards = @cards.index_by(&:id)
      buckets = Array.new(periods + 1) { Hash.new(0) }
      bucket_rows = Array.new(periods + 1) { [] }
      rows.each do |row|
        _, account_id, date, category, amount = row
        card = cards.fetch(account_id)
        back = (0..periods).find { |periods_back| date >= card.statement_period_start(periods_back, today: @today) } || periods
        buckets[back][@group.(category)] += amount
        bucket_rows[back] << row
      end

      reference = @cards.first
      periods.downto(0).map do |back|
        start = reference.statement_period_start(back, today: @today)
        finish = back.zero? ? @today : reference.statement_period_start(back - 1, today: @today) - 1
        label = "#{start.strftime("%b %-d")} – #{finish.strftime(finish.year == start.year ? "%b %-d" : "%b %-d, %Y")}#{" (so far)" if back.zero?}"
        [ { date: start, label:, total: buckets[back].values.sum, by_category: buckets[back] }, bucket_rows[back] ]
      end
    end

    # Builds each point from its attributes and purchases, loading just the
    # largest purchases per point, all in one query.
    def with_top_purchases(points_with_rows)
      top_ids = points_with_rows.map { |_, rows| rows.sort_by { |_, _, _, _, amount| -amount }.map(&:first).uniq.first(TOP_PURCHASES) }
      purchases = Transaction.includes(:account).where(id: top_ids.flatten).index_by(&:id)

      points_with_rows.zip(top_ids).map do |(attributes, rows), ids|
        Point.new(**attributes, purchase_count: rows.size, top_purchases: purchases.values_at(*ids))
      end
    end

    # For "All": how many statement periods back the oldest purchase goes.
    def periods_since(rows)
      oldest = rows.map { |_, _, date, _, _| date }.min or return 0
      periods = 0
      periods += 1 while @cards.all? { |card| oldest < card.statement_period_start(periods, today: @today) }
      periods
    end
end
