module NavigationHelper
  NavItem = Data.define(:key, :label, :path_helper, :icon)

  # Inner SVG markup for 24x24 stroke icons.
  NAV_ITEMS = [
    NavItem.new(key: :overview, label: "Overview", path_helper: :root_path,
      icon: '<rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/>'),
    NavItem.new(key: :transactions, label: "Transactions", path_helper: :transactions_path,
      icon: '<path d="M7 7h13M16 3l4 4-4 4"/><path d="M17 17H4M8 13l-4 4 4 4"/>'),
    NavItem.new(key: :budgets, label: "Budgets", path_helper: :budgets_path,
      icon: '<path d="M21 12A9 9 0 1 1 12 3v9z"/><path d="M15 3.5A9 9 0 0 1 20.5 9H15z"/>'),
    NavItem.new(key: :subscriptions, label: "Subscriptions", path_helper: :subscriptions_path,
      icon: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>'),
    NavItem.new(key: :taxes, label: "Taxes", path_helper: :taxes_path,
      icon: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>')
  ].freeze

  def nav_items = NAV_ITEMS

  def nav_item(key) = NAV_ITEMS.find { |item| item.key == key }

  def nav_icon(item, size: "size-5")
    tag.svg(item.icon.html_safe, class: size, viewBox: "0 0 24 24", fill: "none",
      stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": true)
  end
end
