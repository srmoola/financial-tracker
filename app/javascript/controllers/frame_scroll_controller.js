import { Controller } from "@hotwired/stimulus"

// Keeps the reader's place when a Turbo frame re-renders. A link inside the
// frame can name an element with data-scroll-to (e.g. the list's heading);
// after the frame updates, that element is scrolled into view, but only if
// it's above the top of the screen, so the page never jumps back to the top.
export default class extends Controller {
  remember(event) {
    this.scrollTarget = event.target.closest("[data-scroll-to]")?.dataset.scrollTo
  }

  restore() {
    const element = this.scrollTarget && document.querySelector(this.scrollTarget)
    this.scrollTarget = null
    if (element && element.getBoundingClientRect().top < 0) {
      element.scrollIntoView({ block: "start", behavior: "smooth" })
    }
  }
}
