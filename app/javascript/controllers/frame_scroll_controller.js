import { Controller } from "@hotwired/stimulus"

// Keeps the reader's place when a Turbo frame re-renders. A link inside the
// frame can name an element with data-scroll-to (e.g. the list's heading);
// after the frame updates, that element is scrolled to the top of the screen,
// but only if it's above the top of the screen or below the middle, so the
// page doesn't jump when it's already in view.
export default class extends Controller {
  // Turbo empties the frame before adding the new content, and the browser
  // clamps the page's scroll position while the page is that short, jumping
  // to the top. Put the position back once the new content is in.
  keepPosition(event) {
    const render = event.detail.render
    event.detail.render = (currentElement, newElement) => {
      const top = window.scrollY
      render(currentElement, newElement)
      window.scrollTo({ top, behavior: "instant" })
    }
  }

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
