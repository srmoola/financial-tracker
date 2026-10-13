import { Controller } from "@hotwired/stimulus"

// Swaps an "add a tag" button for its field, and back once the field is left
// empty (or Escape is pressed).
export default class extends Controller {
  static targets = [ "button", "form", "input" ]

  show() {
    this.buttonTarget.hidden = true
    this.formTarget.hidden = false
    this.inputTarget.focus()
  }

  hide() {
    if (this.inputTarget.value.trim()) return

    this.formTarget.hidden = true
    this.buttonTarget.hidden = false
  }

  cancel() {
    this.inputTarget.value = ""
    this.hide()
  }
}
