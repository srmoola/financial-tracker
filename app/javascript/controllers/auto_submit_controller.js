import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as one of its fields changes (e.g. a filter menu).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
