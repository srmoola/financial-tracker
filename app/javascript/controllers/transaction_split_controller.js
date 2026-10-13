import { Controller } from "@hotwired/stimulus"

// Splits a purchase across categories. The dialog lists the parts (a category
// and an amount each); the last part always holds whatever's left, so the
// parts add up to the purchase. Saving needs a category and an amount for each.
export default class extends Controller {
  static targets = ["dialog", "form", "method", "returnTo", "merchant", "total", "parts", "template", "hint", "save", "unsplit"]

  open({ params: { url, merchant, amount, total, category, parts } }) {
    this.formTarget.action = url
    this.methodTarget.value = "patch"
    this.returnToTarget.value = window.location.pathname + window.location.search
    this.merchantTarget.textContent = merchant
    this.totalTarget.textContent = amount
    this.totalCents = Math.round(Number(total) * 100)

    const split = Array.isArray(parts) && parts.length > 0
    this.partsTarget.replaceChildren()
    for (const part of split ? parts : [ { category, amount: "" }, { category: "", amount: "" } ]) this.#append(part)
    this.unsplitTarget.hidden = !split
    this.update()
    this.dialogTarget.showModal()
  }

  // From the category picker's "Split across categories" (see recategorize_controller).
  openFromPicker({ detail }) {
    this.open({ params: detail })
  }

  addPart() {
    this.#append({ category: "", amount: "" })
    this.update()
  }

  removePart(event) {
    event.target.closest("[data-part]").remove()
    this.update()
  }

  // Keeps the last part at whatever's left, and says what's missing.
  update() {
    const rows = this.#rows
    const left = this.totalCents - rows.slice(0, -1).reduce((sum, row) => sum + this.#cents(row), 0)
    rows.forEach((row, index) => {
      const last = index === rows.length - 1
      this.#amount(row).readOnly = last
      if (last) this.#amount(row).value = (left / 100).toFixed(2)
      row.querySelector("[data-remove]").hidden = rows.length <= 2
    })

    const hint =
      left < 0 ? `That's ${this.#currency(-left)} more than the purchase.` :
      rows.some((row) => this.#cents(row) <= 0) ? "Give each part an amount; the last part gets what's left." :
      rows.some((row) => !row.querySelector("select").value) ? "Pick a category for each part." : ""
    this.hintTarget.textContent = hint
    this.saveTarget.disabled = hint !== ""
  }

  unsplit() {
    this.methodTarget.value = "delete"
    this.formTarget.requestSubmit()
  }

  close() {
    this.dialogTarget.close()
  }

  #append({ category, amount }) {
    const row = this.templateTarget.content.firstElementChild.cloneNode(true)
    row.querySelector("select").value = category ?? ""
    this.#amount(row).value = amount === "" ? "" : Number(amount).toFixed(2)
    this.partsTarget.append(row)
  }

  #amount(row) {
    return row.querySelector("input")
  }

  #cents(row) {
    return Math.round(Number(this.#amount(row).value || 0) * 100)
  }

  #currency(cents) {
    return (cents / 100).toLocaleString("en-US", { style: "currency", currency: "USD" })
  }

  get #rows() {
    return [ ...this.partsTarget.children ]
  }
}
