// wrap_it_ruby/controllers/iframe_proxy_controller.js
//
// Manages browser history <-> iframe URL synchronisation.
//
// The proxy host and route segment differ:
//   iframe:  /_proxy/github.com/n-at-han-k
//   browser: /github/n-at-han-k
//
// `host` is used when working with iframe paths (github.com)
// `current` is used when building browser paths (github)
//
// - History sync:  on iframe load, translates the /_proxy prefixed
//                  iframe path back to the browser path and pushes state.
// - Breakout:      if navigation inside the iframe lands on a path
//                  belonging to a DIFFERENT menu route, Turbo.visit
//                  swaps the frame to the new route.
//
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    paths:   Array,   // iframe menu paths, e.g. ["/grafana", "/argocd"]
    current: String,  // route segment, e.g. "github"
    host:    String,  // proxy host, e.g. "github.com"
  }

  connect() {
    this.element.addEventListener("load", this.onLoad)
    window.addEventListener("popstate", this.onPopstate)
  }

  disconnect() {
    this.element.removeEventListener("load", this.onLoad)
    window.removeEventListener("popstate", this.onPopstate)
  }

  onLoad = () => {
    const { pathname, search } = this.element.contentWindow.location
    if (pathname === "about:blank") return

    const iframePath = pathname + search
    const breakout = this.#detectBreakout(iframePath)

    if (breakout) {
      Turbo.visit(breakout, { action: "advance" })
    } else {
      this.#syncHistory(iframePath)
    }
  }

  onPopstate = (event) => {
    const src = event.state?.iframeSrc
    if (src) this.element.contentWindow.location.replace(src)
  }

  // ---- private ----

  // iframe path: /_proxy/github.com/n-at-han-k/repo
  // Extract the host from the proxy path and check if it belongs to
  // a different menu route.
  #detectBreakout(iframePath) {
    if (!iframePath.startsWith("/_proxy/")) return null

    // Pull the host out: "github.com"
    const afterProxy = iframePath.slice("/_proxy/".length)
    const iframeHost = afterProxy.split("/")[0]

    if (iframeHost === this.hostValue) return null

    // Check if this host belongs to another menu route
    // (would need host->route mapping; skip for now)
    return null
  }

  #syncHistory(iframePath) {
    const proxyBase = `/_proxy/${this.hostValue}`
    const subPath = iframePath.startsWith(proxyBase)
      ? iframePath.slice(proxyBase.length)
      : iframePath

    const browserPath = `/${this.currentValue}${subPath}`

    if (browserPath !== window.location.pathname + window.location.search) {
      history.pushState({ iframeSrc: iframePath }, "", browserPath)
    }
  }
}
