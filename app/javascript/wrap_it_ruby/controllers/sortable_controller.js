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
      onStart: (evt) => {
        console.log("[sortable] onStart", evt.item.textContent.trim().slice(0, 30))
      },
      onChange: (evt) => {
        console.log("[sortable] onChange", { newIndex: evt.newIndex, oldIndex: evt.oldIndex })
      },
      onEnd: (evt) => {
        console.log("[sortable] onEnd", { oldIndex: evt.oldIndex, newIndex: evt.newIndex })
        this.#persist(evt.item, evt.newIndex)
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

  #persist(item, newIndex) {
    const url = item.dataset.sortableUpdateUrl
    if (!url) return

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.#csrfToken,
      },
      body: JSON.stringify({ position: newIndex + 1 }),
    })
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
