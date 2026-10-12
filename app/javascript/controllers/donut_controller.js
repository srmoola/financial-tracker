import { Controller } from "@hotwired/stimulus"

// Hovering or focusing a donut slice (or its legend row) highlights both and
// shows that account's balance in the middle of the donut.
export default class extends Controller {
  static targets = ["segment", "item", "label", "value", "detail"]

  connect() {
    this.defaults = {
      label: this.labelTarget.textContent,
      value: this.valueTarget.textContent,
      detail: this.detailTarget.textContent
    }
  }

  show({ params: { index } }) {
    const item = this.itemTargets[index]
    this.#setCenter(item.dataset)
    this.segmentTargets.forEach((segment, i) => segment.classList.toggle("opacity-25", i !== index))
    this.itemTargets.forEach((row, i) => row.classList.toggle("bg-base-200", i === index))
  }

  reset() {
    this.#setCenter(this.defaults)
    this.segmentTargets.forEach((segment) => segment.classList.remove("opacity-25"))
    this.itemTargets.forEach((row) => row.classList.remove("bg-base-200"))
  }

  #setCenter({ label, value, detail }) {
    this.labelTarget.textContent = label
    this.valueTarget.textContent = value
    this.detailTarget.textContent = detail
  }
}
