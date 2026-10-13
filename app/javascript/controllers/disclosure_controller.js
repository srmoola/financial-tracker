import { Controller } from "@hotwired/stimulus"

// Opens and closes a card's panel when its header is clicked, except on the
// header's own controls (e.g. a subscription's tags), which work on their own.
export default class extends Controller {
  static targets = [ "button", "panel" ]

  toggle(event) {
    if (event.target.closest("a, button, input, form") && !this.buttonTarget.contains(event.target)) return

    const open = this.panelTarget.hidden
    this.panelTarget.hidden = !open
    this.buttonTarget.setAttribute("aria-expanded", open)
    this.element.toggleAttribute("data-open", open)
  }
}
