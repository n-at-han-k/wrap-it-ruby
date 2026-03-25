import { Controller } from "@hotwired/stimulus"
import SortableTree from "sortable-tree"
import { patch, post, destroy } from "@rails/request.js"

// Wraps the sortable-tree library as a Stimulus controller.
// Handles drag-to-sort, click-to-edit, and CRUD via modals.

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
      onChange: async ({ nodes, movedNode, srcParentNode, targetParentNode }) => {
        if (!this.hasSortUrlValue) return
        await this.persistTree(nodes)
      },
      onClick: (event, node) => {
        this.editNode(node)
      },
    })

    // Expose global functions for the modal buttons
    this.registerGlobalFunctions()
  }

  disconnect() {
    if (this.tree) {
      this.tree.destroy()
      this.tree = null
    }
    this.unregisterGlobalFunctions()
  }

  // -- Edit --

  editNode(node) {
    const data = node.data
    this._currentEditId = data.id

    document.getElementById("menu-edit-id").value = data.id
    document.getElementById("menu-edit-label").value = data.title || ""
    document.getElementById("menu-edit-icon").value = data.icon || ""
    document.getElementById("menu-edit-route").value = data.route || ""
    document.getElementById("menu-edit-url").value = data.url || ""
    document.getElementById("menu-edit-type").value = data.item_type || "proxy"

    menuSettingsToggleProxyFields("menu-edit")

    $("#menu-edit-modal").modal({ allowMultiple: true }).modal("show")
  }

  async saveNode() {
    const id = document.getElementById("menu-edit-id").value
    const data = {
      label: document.getElementById("menu-edit-label").value,
      icon: document.getElementById("menu-edit-icon").value,
      route: document.getElementById("menu-edit-route").value,
      url: document.getElementById("menu-edit-url").value,
      item_type: document.getElementById("menu-edit-type").value,
    }

    await patch(`/menu/settings/${id}`, {
      body: JSON.stringify(data),
      contentType: "application/json",
      responseKind: "turbo-stream",
    })

    $("#menu-edit-modal").modal("hide")
  }

  async deleteNode() {
    const id = document.getElementById("menu-edit-id").value
    if (!confirm("Delete this item and all its children?")) return

    await destroy(`/menu/settings/${id}`, {
      responseKind: "turbo-stream",
    })

    $("#menu-edit-modal").modal("hide")
  }

  // -- Add --

  showAdd() {
    document.getElementById("menu-add-label").value = ""
    document.getElementById("menu-add-icon").value = ""
    document.getElementById("menu-add-route").value = ""
    document.getElementById("menu-add-url").value = ""
    document.getElementById("menu-add-type").value = "group"
    document.getElementById("menu-add-parent").value = ""

    menuSettingsToggleProxyFields("menu-add")

    $("#menu-add-modal").modal({ allowMultiple: true }).modal("show")
  }

  async createNode() {
    const data = {
      label: document.getElementById("menu-add-label").value,
      icon: document.getElementById("menu-add-icon").value,
      route: document.getElementById("menu-add-route").value,
      url: document.getElementById("menu-add-url").value,
      item_type: document.getElementById("menu-add-type").value,
      parent_id: document.getElementById("menu-add-parent").value || null,
    }

    await post("/menu/settings", {
      body: JSON.stringify(data),
      contentType: "application/json",
      responseKind: "turbo-stream",
    })

    $("#menu-add-modal").modal("hide")
  }

  // -- Sort --

  async persistTree(nodes) {
    const ordering = this.flattenTree(nodes)
    await patch(this.sortUrlValue, {
      body: JSON.stringify({ ordering }),
      contentType: "application/json",
      responseKind: "turbo-stream",
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

  // -- Global functions (called by modal button onclick handlers) --

  registerGlobalFunctions() {
    window.menuSettingsSave = () => this.saveNode()
    window.menuSettingsDelete = () => this.deleteNode()
    window.menuSettingsCreate = () => this.createNode()
    window.menuSettingsShowAdd = () => this.showAdd()
    window.menuSettingsToggleProxyFields = (prefix) => {
      const type = document.getElementById(`${prefix}-type`).value
      const proxyFields = document.getElementById(`${prefix}-proxy-fields`)
      if (proxyFields) {
        proxyFields.style.display = type === "proxy" ? "" : "none"
      }
    }
  }

  unregisterGlobalFunctions() {
    delete window.menuSettingsSave
    delete window.menuSettingsDelete
    delete window.menuSettingsCreate
    delete window.menuSettingsShowAdd
    delete window.menuSettingsToggleProxyFields
  }
}
