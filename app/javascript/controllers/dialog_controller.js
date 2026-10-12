import { Controller } from "@hotwired/stimulus"

// Opens and closes a native <dialog> as a modal.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
