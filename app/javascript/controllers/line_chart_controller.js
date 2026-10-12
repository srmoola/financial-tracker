import { Controller } from "@hotwired/stimulus"

// Crosshair and tooltip for a line chart. Snaps to the day nearest the pointer;
// with the chart focused, the arrow keys (and Home/End) move between days.
// The tooltip's first row is the headline value; the rest are its breakdown.
// Charts with details (a <template> per point) open them in a popover when a
// point is clicked, or with Enter; Escape or a click elsewhere closes it.
export default class extends Controller {
  static targets = ["plot", "crosshair", "dot", "tooltip", "date", "rows", "detail", "popover", "popoverBody"]
  static values = { points: Array } // [[x%, date label, [y% per line], [[label, value, color], ...]], ...]

  move(event) {
    this.#show(this.#indexAt(event.clientX))
  }

  open(event) {
    const rect = this.plotTarget.getBoundingClientRect()
    const clicked = event.type === "click"
    if (clicked) this.#show(this.#indexAt(event.clientX))
    if (this.index === undefined) return

    const [x, , ys] = this.pointsValue[this.index]
    const template = this.detailTargets.find((detail) => Number(detail.dataset.index) === this.index)
    this.popoverBodyTarget.replaceChildren(template.content.cloneNode(true))

    this.popoverTarget.hidden = false
    this.tooltipTarget.hidden = true

    // Beside the point, on whichever side has room, but never off screen; level
    // with the click (or the highest line, from the keyboard), opening downward
    // from the top half.
    const width = this.popoverTarget.offsetWidth
    const pointX = (x / 100) * rect.width
    const left = x > 55 ? pointX - 12 - width : pointX + 12
    const margin = 8
    const top = clicked ? event.clientY - rect.top : (Math.min(...ys) / 100) * rect.height
    this.popoverTarget.style.left = `${Math.min(Math.max(left, margin - rect.left), window.innerWidth - margin - rect.left - width)}px`
    this.popoverTarget.style.top = `${top}px`
    this.popoverTarget.style.transform = top > rect.height / 2 ? "translateY(-100%)" : ""
  }

  close() {
    if (this.hasPopoverTarget) this.popoverTarget.hidden = true
  }

  closeOutside(event) {
    if (!this.plotTarget.contains(event.target) && !this.popoverTarget.contains(event.target)) this.close()
  }

  focus() {
    this.#show(this.#lastIndex)
  }

  key(event) {
    if (event.key === "Enter" && this.hasPopoverTarget) return this.open(event)

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
    // The popover takes the tooltip's place while it's open.
    if (this.hasPopoverTarget && !this.popoverTarget.hidden) this.tooltipTarget.hidden = true
  }

  #indexAt(clientX) {
    const rect = this.plotTarget.getBoundingClientRect()
    const ratio = Math.min(Math.max((clientX - rect.left) / rect.width, 0), 1)
    return Math.round(ratio * this.#lastIndex)
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
