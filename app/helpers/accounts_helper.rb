module AccountsHelper
  # Plaid subtypes are lowercase ("cd", "money market", "401k"). Words that are
  # acronyms or have a set spelling get it; the rest are capitalized.
  SUBTYPE_WORDS = { "cd" => "CD", "hsa" => "HSA", "ira" => "IRA", "401k" => "401(k)", "403b" => "403(b)", "457b" => "457(b)", "529" => "529" }.freeze
  # Whole subtypes whose Plaid name is shorthand.
  SUBTYPE_NAMES = { "roth" => "Roth IRA" }.freeze
  GROUP_ORDER = [ *NetWorthBreakdown::GROUPS.keys, :debts ].freeze

  def account_subtype_label(subtype)
    SUBTYPE_NAMES.fetch(subtype.to_s) do
      subtype.to_s.split.map { |word| SUBTYPE_WORDS.fetch(word) { word.capitalize } }.join(" ").presence
    end
  end

  # Checking, savings, investments, then credit cards (as on the dashboard), by name within each.
  def sorted_accounts(accounts)
    accounts.sort_by { |account| [ GROUP_ORDER.index(NetWorthBreakdown.group_for(account)), account.name ] }
  end

  # The dashboard color for the account's category; nil for credit cards.
  def account_group_color(account)
    DonutChartHelper::CATEGORY_COLORS[NetWorthBreakdown.group_for(account)]
  end

  # Up to two letters for an institution's badge ("First Platypus Bank" -> "FP").
  def institution_initials(name)
    name.to_s.scan(/\b[[:alnum:]]/).first(2).join.upcase.presence || "?"
  end
end
