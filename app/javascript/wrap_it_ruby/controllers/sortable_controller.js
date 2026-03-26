import { Controller } from "@hotwired/stimulus"
import SortableJS from "sortablejs"

export default class extends Controller {
  static values = {
    resourceName: { type: String, default: "menu_item" },
    animation: { type: Number, default: 150 },
  }

  connect() {
    // If reconnecting after a DOM move, skip re-init
    if (this._disconnectTimer) {
      clearTimeout(this._disconnectTimer)
      this._disconnectTimer = null
      return
    }

    this.sortable = SortableJS.create(this.element, {
      group: {
        name: this.resourceNameValue,
        pull: true,
        put: true,
      },
      animation: this.animationValue,
      draggable: "> .ui.attached.segment",
      handle: ".drag-handle",
      forceFallback: true,
      fallbackOnBody: true,
      emptyInsertThreshold: 20,
      onClone: (evt) => {
        evt.clone.querySelectorAll("[data-controller]").forEach(el => {
          el.removeAttribute("data-controller")
        })
      },
      onEnd: (evt) => {
        this.#persist(evt.item, evt.newIndex, evt.to)
      },
    })
  }

  disconnect() {
    // Debounce: SortableJS swaps cause disconnect+reconnect in same tick.
    // Wait before destroying so the reconnect can cancel it.
    this._disconnectTimer = setTimeout(() => {
      if (this.sortable) {
        this.sortable.destroy()
        this.sortable = null
      }
    }, 100)
  }

  #persist(item, newIndex, toContainer) {
    const url = item.dataset.sortableUpdateUrl
    if (!url) return

    const parentEl = toContainer.closest("[data-sortable-update-url]")
    const parentId = parentEl
      ? parentEl.dataset.sortableUpdateUrl.match(/\/(\d+)$/)?.[1]
      : null

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.#csrfToken,
      },
      body: JSON.stringify({ position: newIndex + 1, parent_id: parentId }),
    })
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
