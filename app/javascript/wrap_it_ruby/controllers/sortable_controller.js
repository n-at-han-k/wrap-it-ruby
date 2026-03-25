import Sortable from "@stimulus-components/sortable"
import { patch } from "@rails/request.js"

// Extends stimulus-sortable to support nested sortable lists with Turbo Stream responses.
//
// Each container gets its own Sortable instance. Items can be dragged
// within a container (reorder) or between containers sharing the same
// group name (reparent).
//
// Data attributes on the container:
//   data-controller="wrap-it-ruby--sortable"
//   data-wrap-it-ruby--sortable-group-value="items"  — SortableJS group name
//   data-sortable-parent-id="42"                     — parent_id for items in this container
//
// Data attributes on each draggable item:
//   data-sortable-update-url="/menu/settings/7/sort"  — PATCH endpoint
//   data-sortable-handle on the grip element

export default class extends Sortable {
  static values = {
    ...Sortable.values,
    group: { type: String, default: "" },
  }

  get options() {
    return {
      animation: this.hasAnimationValue ? this.animationValue : 150,
      handle: this.hasHandleValue ? this.handleValue : "[data-sortable-handle]",
      ghostClass: "sortable-ghost",
      group: this.groupValue || undefined,
      onEnd: this.onEnd.bind(this),
      // Disable parent's onUpdate — we use onEnd for both same-list and cross-list moves
      onUpdate: () => {},
    }
  }

  get defaultOptions() {
    return { animation: 150 }
  }

  async onEnd(event) {
    const { item, newIndex, oldIndex, to, from } = event
    if (oldIndex === newIndex && from === to) return

    const url = item.dataset.sortableUpdateUrl
    if (!url) return

    const parentId = to.dataset.sortableParentId || ""

    const data = new FormData()
    data.append("position", newIndex + 1)
    data.append("parent_id", parentId)

    await patch(url, { body: data, responseKind: "turbo-stream" })
  }
}
