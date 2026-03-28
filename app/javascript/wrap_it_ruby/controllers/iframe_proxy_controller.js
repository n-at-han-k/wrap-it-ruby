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
// - Tab sync:      mirrors the iframe's <title> and favicon into the
//                  parent page so the browser tab reflects the proxied
//                  content.
//
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    paths:   Array,   // iframe menu paths, e.g. ["/grafana", "/argocd"]
    current: String,  // route segment, e.g. "github"
    host:    String,  // proxy host, e.g. "github.com"
  }

  #originalTitle
  #originalIcons

  connect() {
    this.#originalTitle = document.title
    this.#originalIcons = [...document.querySelectorAll('link[rel="icon"], link[rel="shortcut icon"]')]

    this.element.addEventListener("load", this.onLoad)
    window.addEventListener("popstate", this.onPopstate)
    window.addEventListener("message", this.onMessage)
  }

  disconnect() {
    document.title = this.#originalTitle
    this.#removeIcons()
    this.#originalIcons.forEach(el => document.head.appendChild(el))

    this.element.removeEventListener("load", this.onLoad)
    window.removeEventListener("popstate", this.onPopstate)
    window.removeEventListener("message", this.onMessage)
  }

  onLoad = () => {
    const iframePath = this.#currentIframePath()
    if (!iframePath || iframePath === "about:blank") return

    const breakout = this.#detectBreakout(iframePath)

    if (breakout) {
      Turbo.visit(breakout, { action: "advance" })
    } else {
      this.#syncHistory(iframePath)
      this.#syncTab()
    }
  }

  onPopstate = (event) => {
    const src = event.state?.iframeSrc
    if (src) this.element.contentWindow.location.replace(src)
  }

  onMessage = (event) => {
    if (event.source !== this.element.contentWindow) return

    const data = event.data
    if (!data || data.type !== "wrap-it-ruby:navigation") return

    const iframePath = data.iframePath
    if (typeof iframePath !== "string" || !iframePath.startsWith("/_proxy/")) return

    const breakout = this.#detectBreakout(iframePath)
    if (breakout) {
      Turbo.visit(breakout, { action: "advance" })
      return
    }

    this.#syncHistory(iframePath)
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

    if (browserPath !== window.location.pathname + window.location.search + window.location.hash) {
      history.pushState({ iframeSrc: iframePath }, "", browserPath)
    }
  }

  #currentIframePath() {
    try {
      const { pathname, search, hash } = this.element.contentWindow.location
      return pathname + search + hash
    } catch (_) {
      return null
    }
  }

  // Read the iframe's <title> and favicon, apply them to the parent page.
  #syncTab() {
    try {
      const doc = this.element.contentDocument
      if (!doc) return

      if (doc.title) document.title = doc.title

      const icon = doc.querySelector('link[rel="icon"], link[rel="shortcut icon"]')
      if (icon) {
        const href = this.#resolveHref(icon.getAttribute("href"))
        if (href) this.#setFavicon(href)
      }
    } catch (_) {
      // cross-origin iframe – cannot access contentDocument
    }
  }

  // Resolve a favicon href from the iframe document.
  // Absolute / data URIs pass through unchanged; root-relative and
  // relative paths are routed through the proxy.
  #resolveHref(raw) {
    if (!raw) return null
    if (raw.startsWith("data:") || /^https?:\/\//.test(raw) || raw.startsWith("//")) return raw

    if (raw.startsWith("/")) {
      return `/_proxy/${this.hostValue}${raw}`
    }

    // Relative path – resolve against the iframe's current directory
    const dir = this.element.contentWindow.location.pathname.replace(/\/[^/]*$/, "/")
    return `${dir}${raw}`
  }

  #setFavicon(href) {
    this.#removeIcons()
    const link = document.createElement("link")
    link.rel = "icon"
    link.href = href
    document.head.appendChild(link)
  }

  #removeIcons() {
    document.querySelectorAll('link[rel="icon"], link[rel="shortcut icon"]').forEach(el => el.remove())
  }
}
