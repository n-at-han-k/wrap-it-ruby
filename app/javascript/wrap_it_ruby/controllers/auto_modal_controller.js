import { Controller } from "@hotwired/stimulus"

// Auto-shows a Fomantic-UI modal on connect and navigates back when closed.
//
// Place on a parent element wrapping a Modal component:
//
//   <div data-controller="wrap-it-ruby--auto-modal">
//     <div class="ui modal" data-controller="fui-modal">...</div>
//   </div>
//
export default class extends Controller {
  connect() {
    // Delay to ensure fui-modal has initialized the jQuery modal
    setTimeout(() => {
      this.modal = this.element.querySelector(".ui.modal")
      if (!this.modal) return

      $(this.modal).modal("setting", "onHidden", () => this.navigateBack())
      $(this.modal).modal("show")
    }, 0)
  }

  navigateBack() {
    history.back()
  }
}
