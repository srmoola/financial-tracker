import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as one of its fields changes (e.g. a filter menu),
// or, while typing (e.g. a search box), once the typing stops for three quarters of a second.
export default class extends Controller {
  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  submitSoon() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 750)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
