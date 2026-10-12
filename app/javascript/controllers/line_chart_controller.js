import { Controller } from "@hotwired/stimulus"

// Crosshair and tooltip for a line chart. Snaps to the day nearest the pointer;
// with the chart focused, the arrow keys (and Home/End) move between days.
// The tooltip's first row is the headline value; the rest are its breakdown.
export default class extends Controller {
  static targets = ["plot", "crosshair", "dot", "tooltip", "date", "rows"]
  static values = { points: Array } // [[x%, date label, [y% per line], [[label, value, color], ...]], ...]

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
    const [x, date, ys, rows] = this.pointsValue[index]

    this.crosshairTarget.style.left = `${x}%`
    this.dotTargets.forEach((dot, line) => {
      dot.style.left = `${x}%`
      dot.style.top = `${ys[line]}%`
    })
    this.tooltipTarget.style.left = `${x}%`
    // Keep the tooltip beside the crosshair, on whichever side has room.
    this.tooltipTarget.style.transform = x > 55 ? "translateX(calc(-100% - 12px))" : "translateX(12px)"
    this.dateTarget.textContent = date
    this.rowsTarget.replaceChildren(...rows.map((row, position) => this.#row(row, position === 0)))

    this.#markers.forEach((element) => (element.hidden = false))
  }

  #row([label, value, color], headline) {
    const row = document.createElement("div")
    row.className = headline ? "flex items-baseline justify-between gap-6 text-sm font-semibold" : "flex items-center gap-2 text-xs"

    if (color) {
      const key = document.createElement("span")
      key.className = "h-0.5 w-3 shrink-0 rounded-full"
      key.style.backgroundColor = color
      row.append(key)
    }

    const name = document.createElement("span")
    name.className = headline ? "" : "flex-1 text-base-content/70"
    name.textContent = label
    const amount = document.createElement("span")
    amount.className = headline ? "tabular-nums" : "font-medium tabular-nums"
    amount.textContent = value

    row.append(name, amount)
    return row
  }

  get #lastIndex() {
    return this.pointsValue.length - 1
  }

  get #markers() {
    return [this.crosshairTarget, this.tooltipTarget, ...this.dotTargets]
  }
}
