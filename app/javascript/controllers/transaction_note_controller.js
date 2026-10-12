import { Controller } from "@hotwired/stimulus"

// Opens the note editor for one transaction: a single <dialog> with a form
// that saves (or removes) the note, with a live character count.
export default class extends Controller {
  static targets = ["dialog", "form", "returnTo", "merchant", "amount", "field", "count", "remove"]
  static values = { maxLength: Number }

  open({ params: { url, merchant, amount, note } }) {
    this.formTarget.action = url
    this.returnToTarget.value = window.location.pathname + window.location.search
    this.merchantTarget.textContent = merchant
    this.amountTarget.textContent = amount
    this.fieldTarget.value = note || ""
    this.removeTarget.hidden = !note
    this.count()

    this.dialogTarget.showModal()
    this.fieldTarget.focus()
    this.fieldTarget.setSelectionRange(this.fieldTarget.value.length, this.fieldTarget.value.length)
  }

  count() {
    this.countTarget.textContent = `${this.fieldTarget.value.length}/${this.maxLengthValue}`
  }

  remove() {
    this.fieldTarget.value = ""
    this.formTarget.requestSubmit()
  }

  // Cmd/Ctrl+Enter saves, like most note fields.
  submitOnShortcut(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }

  close() {
    this.dialogTarget.close()
  }
}
