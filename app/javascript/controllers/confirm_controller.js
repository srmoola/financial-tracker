import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Asks with the app's own dialog, instead of the browser's confirm box, before
// a form with data-turbo-confirm submits. The form (or its button) can name the
// confirming button with data-confirm-button, e.g. "Delete budget".
export default class extends Controller {
  static targets = [ "message", "accept" ]

  connect() {
    Turbo.config.forms.confirm = (message, form, submitter) => this.ask(message, submitter?.dataset.confirmButton || form.dataset.confirmButton)
  }

  disconnect() {
    Turbo.config.forms.confirm = undefined
  }

  ask(message, button = "Confirm") {
    this.messageTarget.textContent = message
    this.acceptTarget.textContent = button
    this.element.returnValue = ""
    this.element.showModal()
    return new Promise(resolve => {
      this.element.addEventListener("close", () => resolve(this.element.returnValue === "confirm"), { once: true })
    })
  }
}
