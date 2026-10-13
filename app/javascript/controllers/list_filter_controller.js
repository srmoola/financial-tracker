import { Controller } from "@hotwired/stimulus"

// Hides the items that don't match what's typed, e.g. in a long list of
// checkboxes. Each item has its searchable text in data-filter-text.
export default class extends Controller {
  static targets = ["input", "item", "empty"]

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let shown = 0
    this.itemTargets.forEach((item) => {
      item.hidden = query !== "" && !item.dataset.filterText.includes(query)
      if (!item.hidden) shown++
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
  }
}
