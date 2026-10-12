# Credit card spending over time, in the same categories as the spending donut.
# "This month" shows how spending builds up day by day through the statement
# period; longer ranges show the total for each statement period, using each
# card's own statement dates.
class SpendingHistory
  Point = Data.define(:date, :label, :total, :by_category)

  attr_reader :points

  # `purchases`: the purchases (positive amounts) to chart, already limited to
  # the range. `category_keys`: the donut's named categories; anything else is
  # counted as :other. `periods_back`: statement periods before the current
  # one (nil for all time). Daily for "This month" (periods_back 0).
  def initialize(purchases, cards:, category_keys:, periods_back:, today: Date.current)
    @cards = cards
    @today = today
    @group = ->(category) { category_keys.include?(category) ? category : :other }
    rows = purchases.pluck(:account_id, :date, Arel.sql(Transaction::EFFECTIVE_CATEGORY_SQL), :amount)

    @daily = periods_back&.zero?
    @points = @daily ? daily_points(rows) : period_points(rows, periods_back || periods_since(rows))
  end

  # True for "This month": points are days with running totals, not statement periods.
  def daily? = @daily
  def empty? = points.none? { |point| point.total.positive? }

  private
    # A running total per category for each day of the current statement period.
    def daily_points(rows)
      by_day = Hash.new { |hash, day| hash[day] = Hash.new(0) }
      rows.each { |_, date, category, amount| by_day[date][@group.(category)] += amount }

      running = Hash.new(0)
      (@cards.map { |card| card.current_statement_start(today: @today) }.min..@today).map do |day|
        by_day[day].each { |category, amount| running[category] += amount }
        Point.new(date: day, label: day.strftime("%b %-d, %Y"), total: running.values.sum, by_category: running.dup)
      end
    end

    # Totals per category for each statement period, oldest first. Each
    # transaction lands in its own card's period; labels use the first card's dates.
    def period_points(rows, periods)
      cards = @cards.index_by(&:id)
      buckets = Array.new(periods + 1) { Hash.new(0) }
      rows.each do |account_id, date, category, amount|
        card = cards.fetch(account_id)
        back = (0..periods).find { |periods_back| date >= card.statement_period_start(periods_back, today: @today) } || periods
        buckets[back][@group.(category)] += amount
      end

      reference = @cards.first
      periods.downto(0).map do |back|
        start = reference.statement_period_start(back, today: @today)
        finish = back.zero? ? @today : reference.statement_period_start(back - 1, today: @today) - 1
        label = "#{start.strftime("%b %-d")} – #{finish.strftime(finish.year == start.year ? "%b %-d" : "%b %-d, %Y")}#{" (so far)" if back.zero?}"
        Point.new(date: start, label:, total: buckets[back].values.sum, by_category: buckets[back])
      end
    end

    # For "All": how many statement periods back the oldest purchase goes.
    def periods_since(rows)
      oldest = rows.map { |_, date, _, _| date }.min or return 0
      periods = 0
      periods += 1 while @cards.all? { |card| oldest < card.statement_period_start(periods, today: @today) }
      periods
    end
end
