import { Controller } from "@hotwired/stimulus"

// Keeps the reader's place when a Turbo frame re-renders. A link inside the
// frame can name an element with data-scroll-to (e.g. the list's heading);
// after the frame updates, that element is scrolled to the top of the screen,
// but only if it's above the top of the screen or below the middle, so the
// page doesn't jump when it's already in view.
export default class extends Controller {
  remember(event) {
    this.scrollTarget = event.target.closest("[data-scroll-to]")?.dataset.scrollTo
  }

  restore() {
    const element = this.scrollTarget && document.querySelector(this.scrollTarget)
    this.scrollTarget = null
    const top = element?.getBoundingClientRect().top
    if (element && (top < 0 || top > window.innerHeight / 2)) {
      element.scrollIntoView({ block: "start", behavior: "smooth" })
    }
  }
}
