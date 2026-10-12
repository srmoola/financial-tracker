import { Controller } from "@hotwired/stimulus"

// Opens the category picker for one transaction. The picker is a single
// <dialog> with a form whose buttons each submit a category; this fills in
// which transaction it's for and marks its current category.
export default class extends Controller {
  static targets = ["dialog", "form", "returnTo", "merchant", "amount", "option", "reset", "plaidCategory"]

  open({ params: { url, merchant, amount, category, plaidCategory, plaidLabel } }) {
    this.formTarget.action = url
    this.returnToTarget.value = window.location.pathname + window.location.search
    this.merchantTarget.textContent = merchant
    this.amountTarget.textContent = amount

    this.optionTargets.forEach((option) => {
      const current = option.value === category
      option.setAttribute("aria-pressed", current)
      option.classList.toggle("btn-active", current)
      option.classList.toggle("btn-primary", current)
    })

    // "Reset" only makes sense when the user has changed Plaid's category.
    const changed = Boolean(plaidCategory) ? category !== plaidCategory : Boolean(category)
    this.resetTarget.hidden = !changed
    this.plaidCategoryTarget.textContent = plaidLabel

    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
