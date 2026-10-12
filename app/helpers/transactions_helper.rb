module TransactionsHelper
  # Web addresses in notes: http(s):// or www., stopping before trailing punctuation.
  NOTE_URL_PATTERN = /\b(?:https?:\/\/|www\.)[^\s<>"]*[^\s<>".,:;!?)\]'}]/i

  # A note with its web addresses turned into links (opening in a new tab).
  # Everything else is escaped, so a note can't add its own HTML.
  def linkify_note(note)
    parts = note.to_s.split(/(#{NOTE_URL_PATTERN})/o)
    safe_join(parts.map.with_index do |part, index|
      next part unless index.odd? # odd parts are the captured URLs

      url = part.match?(%r{\Ahttps?://}i) ? part : "https://#{part}"
      link_to part, url, target: "_blank", rel: "noopener noreferrer nofollow", class: "link break-all"
    end)
  end

  # Page numbers to show: the first, the last, and the current page with its
  # neighbors, with :gap where pages are skipped (e.g. 1 … 4 5 6 … 12).
  def page_window(page, page_count)
    pages = [ 1, page - 1, page, page + 1, page_count ].select { |number| number.between?(1, page_count) }.uniq.sort
    pages.each_with_index.flat_map { |number, index| index.positive? && number - pages[index - 1] > 1 ? [ :gap, number ] : [ number ] }
  end

  # A time range (see TransactionsController::RANGES) as a heading ("Your last
  # 3 statements and this month, since Jun 16") and as the end of a sentence
  # ("No purchases since Jun 16").
  def range_heading(range, cards, earliest_date)
    return earliest_date ? "All time, since #{earliest_date.strftime("%b %-d, %Y")}" : "All time" if range == "all"

    statement_range_heading(cards, TransactionsController::STATEMENTS_BACK.fetch(range))
  end

  def range_phrase(range, cards)
    case range
    when "all" then "yet"
    when "statement" then "this statement period"
    else statement_range_start(cards, TransactionsController::STATEMENTS_BACK.fetch(range))
    end
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
