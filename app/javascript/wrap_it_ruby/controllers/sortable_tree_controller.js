import { Controller } from "@hotwired/stimulus"
import SortableTree from "sortable-tree"
import { patch } from "@rails/request.js"

// Wraps the sortable-tree library as a Stimulus controller.
// Handles drag-to-sort; click navigates to the edit page.

export default class extends Controller {
  static values = {
    nodes: Array,
    sortUrl: String,
    editUrlTemplate: String,
    lockRoot: { type: Boolean, default: true },
    collapseLevel: { type: Number, default: 2 },
  }

  connect() {
    this.tree = new SortableTree({
      nodes: this.nodesValue,
      element: this.element,
      lockRootLevel: this.lockRootValue,
      initCollapseLevel: this.collapseLevelValue,
      styles: {
        tree: "st-tree",
        node: "st-node",
        nodeHover: "st-node--hover",
        nodeDragging: "st-node--dragging",
        nodeDropBefore: "st-node--drop-before",
        nodeDropInside: "st-node--drop-inside",
        nodeDropAfter: "st-node--drop-after",
        label: "st-label",
        subnodes: "st-subnodes",
        collapse: "st-collapse",
      },
      icons: {
        collapsed: '<i class="caret right icon"></i>',
        open: '<i class="caret down icon"></i>',
      },
      renderLabel: (data) => {
        const icon = data.icon ? `<i class="${data.icon} icon"></i> ` : ""
        const route = data.route ? `<span class="st-route">${data.route}</span>` : ""
        const typeBadge = data.item_type === "group"
          ? '<span class="ui mini label">group</span> '
          : ""
        return `<span class="st-label-inner">${icon}${typeBadge}<strong>${data.title}</strong>${route}</span>`
      },
      onChange: async ({ nodes }) => {
        if (!this.hasSortUrlValue) return
        await this.persistTree(nodes)
      },
      onClick: (_event, node) => {
        this.navigateToEdit(node)
      },
    })
  }

  disconnect() {
    if (this.tree) {
      this.tree.destroy()
      this.tree = null
    }
  }

  navigateToEdit(node) {
    if (!this.hasEditUrlTemplateValue) return
    const url = this.editUrlTemplateValue.replace(":id", node.data.id)
    window.location.href = url
  }

  async persistTree(nodes) {
    const ordering = this.flattenTree(nodes)
    await patch(this.sortUrlValue, {
      body: JSON.stringify({ ordering }),
      contentType: "application/json",
      responseKind: "html",
    })
  }

  flattenTree(nodes, parentId = null) {
    const result = []
    nodes.forEach((node, index) => {
      result.push({
        id: node.element.data.id,
        parent_id: parentId,
        position: index + 1,
      })
      if (node.subnodes && node.subnodes.length > 0) {
        result.push(...this.flattenTree(node.subnodes, node.element.data.id))
      }
    })
    return result
  }
}
