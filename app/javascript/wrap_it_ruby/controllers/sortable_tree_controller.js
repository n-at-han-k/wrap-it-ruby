import { Controller } from "@hotwired/stimulus"
import SortableTree from "sortable-tree"
import { patch } from "@rails/request.js"

// Wraps the sortable-tree library as a Stimulus controller.
//
// Usage:
//   <div data-controller="wrap-it-ruby--sortable-tree"
//        data-wrap-it-ruby--sortable-tree-nodes-value='[...]'
//        data-wrap-it-ruby--sortable-tree-sort-url-value="/menu/settings/sort">
//   </div>
//
// The nodes JSON matches sortable-tree's format:
//   [{ data: { id: 1, title: "Home", icon: "home" }, nodes: [...] }]

export default class extends Controller {
  static values = {
    nodes: Array,
    sortUrl: String,
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
        tree: "ui styled fluid tree",
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
        return `<span class="st-label-inner">${icon}<strong>${data.title}</strong>${route}</span>`
      },
      onChange: async ({ nodes, movedNode, srcParentNode, targetParentNode }) => {
        if (!this.hasSortUrlValue) return
        await this.persistTree(nodes)
      },
    })
  }

  disconnect() {
    if (this.tree) {
      this.tree.destroy()
      this.tree = null
    }
  }

  // Walk the tree and send the full ordering to the server.
  async persistTree(nodes) {
    const ordering = this.flattenTree(nodes)
    await patch(this.sortUrlValue, {
      body: JSON.stringify({ ordering }),
      contentType: "application/json",
      responseKind: "turbo-stream",
    })
  }

  // Convert the tree structure to a flat array of { id, parent_id, position }.
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
