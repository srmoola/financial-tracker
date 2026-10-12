module TransactionsHelper
  # Page numbers to show: the first, the last, and the current page with its
  # neighbors, with :gap where pages are skipped (e.g. 1 … 4 5 6 … 12).
  def page_window(page, page_count)
    pages = [ 1, page - 1, page, page + 1, page_count ].select { |number| number.between?(1, page_count) }.uniq.sort
    pages.each_with_index.flat_map { |number, index| index.positive? && number - pages[index - 1] > 1 ? [ :gap, number ] : [ number ] }
  end

  # When "This month" starts, e.g. "since Sep 17", or per card if they differ.
  def statement_range_description(cards)
    starts = cards.map(&:current_statement_start).uniq
    starts.one? ? "since #{starts.first.strftime("%b %-d")}" : "since each card's last statement"
  end
end
