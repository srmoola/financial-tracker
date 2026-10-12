import { Controller } from "@hotwired/stimulus"

// Crosshair and tooltip for a line chart. Snaps to the day nearest the pointer;
// with the chart focused, the arrow keys (and Home/End) move between days.
export default class extends Controller {
  static targets = ["plot", "crosshair", "dot", "tooltip", "value", "date"]
  static values = { points: Array } // [[x%, y%, date label, value label], ...]

  move(event) {
    const rect = this.plotTarget.getBoundingClientRect()
    const ratio = Math.min(Math.max((event.clientX - rect.left) / rect.width, 0), 1)
    this.#show(Math.round(ratio * this.#lastIndex))
  }

  focus() {
    this.#show(this.#lastIndex)
  }

  key(event) {
    const moves = { ArrowLeft: this.index - 1, ArrowRight: this.index + 1, Home: 0, End: this.#lastIndex }
    if (!(event.key in moves)) return

    event.preventDefault()
    this.#show(Math.min(Math.max(moves[event.key], 0), this.#lastIndex))
  }

  hide() {
    this.index = undefined
    this.#markers.forEach((element) => (element.hidden = true))
  }

  #show(index) {
    this.index = index
    const [x, y, date, value] = this.pointsValue[index]

    this.crosshairTarget.style.left = `${x}%`
    this.dotTarget.style.left = `${x}%`
    this.dotTarget.style.top = `${y}%`
    this.tooltipTarget.style.left = `${x}%`
    // Keep the tooltip beside the crosshair, on whichever side has room.
    this.tooltipTarget.style.transform = x > 60 ? "translateX(calc(-100% - 12px))" : "translateX(12px)"
    this.valueTarget.textContent = value
    this.dateTarget.textContent = date

    this.#markers.forEach((element) => (element.hidden = false))
  }

  get #lastIndex() {
    return this.pointsValue.length - 1
  }

  get #markers() {
    return [this.crosshairTarget, this.dotTarget, this.tooltipTarget]
  }
}
