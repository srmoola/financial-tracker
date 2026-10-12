module TransactionsHelper
  # Page numbers to show: the first, the last, and the current page with its
  # neighbors, with :gap where pages are skipped (e.g. 1 … 4 5 6 … 12).
  def page_window(page, page_count)
    pages = [ 1, page - 1, page, page + 1, page_count ].select { |number| number.between?(1, page_count) }.uniq.sort
    pages.each_with_index.flat_map { |number, index| index.positive? && number - pages[index - 1] > 1 ? [ :gap, number ] : [ number ] }
  end

  # What a range covers, e.g. "Your last 3 statements and this month, since Jun 16".
  # Cards with different statement dates are described together.
  def statement_range_heading(cards, periods_back)
    covers =
      case periods_back
      when 0 then "This month"
      when 1 then "Your last statement and this month"
      else "Your last #{periods_back} statements and this month"
      end
    "#{covers}, #{statement_range_start(cards, periods_back)}"
  end

  def statement_range_start(cards, periods_back)
    starts = cards.map { |card| card.statement_period_start(periods_back) }.uniq
    return "since each card's statement date" unless starts.one?

    start = starts.first
    "since #{start.strftime(start.year == Date.current.year ? "%b %-d" : "%b %-d, %Y")}"
  end
end
