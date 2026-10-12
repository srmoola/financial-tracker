import { Controller } from "@hotwired/stimulus"

// Hovering or focusing a donut slice (or its legend row) highlights both and
// shows that slice's value in the middle of the donut. A selected slice (e.g.
// the category the list is filtered to) stays highlighted when nothing is
// hovered; clicking a slice follows its legend row's link.
export default class extends Controller {
  static targets = ["segment", "item", "label", "value", "detail"]
  static values = { selected: { type: Number, default: -1 } }

  connect() {
    this.defaults = {
      label: this.labelTarget.textContent,
      value: this.valueTarget.textContent,
      detail: this.detailTarget.textContent
    }
    this.reset()
  }

  show({ params: { index } }) {
    this.#highlight(index)
  }

  reset() {
    if (this.selectedValue >= 0) {
      this.#highlight(this.selectedValue)
    } else {
      this.#setCenter(this.defaults)
      this.segmentTargets.forEach((segment) => segment.classList.remove("opacity-25"))
      this.itemTargets.forEach((row) => row.classList.remove("bg-base-200"))
    }
  }

  select({ params: { index } }) {
    this.itemTargets[index]?.click()
  }

  #highlight(index) {
    this.#setCenter(this.itemTargets[index].dataset)
    this.segmentTargets.forEach((segment, i) => segment.classList.toggle("opacity-25", i !== index))
    this.itemTargets.forEach((row, i) => row.classList.toggle("bg-base-200", i === index))
  }

  #setCenter({ label, value, detail }) {
    this.labelTarget.textContent = label
    this.valueTarget.textContent = value
    this.detailTarget.textContent = detail
  }
}
