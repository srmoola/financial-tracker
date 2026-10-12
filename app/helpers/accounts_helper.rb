module AccountsHelper
  # Plaid subtypes are lowercase ("cd", "money market", "401k"). Words that are
  # acronyms or have a set spelling get it; the rest are capitalized.
  SUBTYPE_WORDS = { "cd" => "CD", "hsa" => "HSA", "ira" => "IRA", "401k" => "401(k)", "403b" => "403(b)", "457b" => "457(b)", "529" => "529" }.freeze

  def account_subtype_label(subtype)
    subtype.to_s.split.map { |word| SUBTYPE_WORDS.fetch(word) { word.capitalize } }.join(" ").presence
  end
end
