// interception.js — Injected into proxied HTML by ScriptInjectionMiddleware.
//
// Rewrites cross-origin URLs through /_proxy/{host} and stamps
// X-Proxy-Host on fetch/XHR so RootRelativeProxyMiddleware can route
// root-relative requests.
//
// Intercepts: fetch, XMLHttpRequest, WebSocket, EventSource,
//             <a> clicks, <form> submissions.
//
(function (window) {
  'use strict';

  var PROXY_BASE = '/_proxy';

  // Block service worker registration — proxied apps share the proxy
  // origin so a SW registered by one app (e.g. code-server) would
  // intercept requests for all proxied sites with stale cached paths.
  if (navigator.serviceWorker) {
    navigator.serviceWorker.register = () => Promise.resolve()
  }

  var _fetch        = window.fetch;
  var _XHR          = window.XMLHttpRequest;
  var _xhrOpen      = _XHR.prototype.open;
  var _xhrSend      = _XHR.prototype.send;
  var _xhrSetHeader = _XHR.prototype.setRequestHeader;
  var _WebSocket    = window.WebSocket;
  var _EventSource  = window.EventSource;

  const PROXY_HOST = window.__proxyHost;
  const NAV_MESSAGE_TYPE = 'wrap-it-ruby:navigation'

  const SPECIAL_SCHEME = /^(javascript:|mailto:|tel:|data:|blob:)/i

  const isHashOnly = (url) => typeof url === 'string' && url.startsWith('#')

  const normalizeProxiedPath = (path) => {
    if (typeof path !== 'string') return path
    const prefix = `/_proxy/${PROXY_HOST}`
    let normalized = path
    while (normalized.startsWith(`${prefix}${prefix}`)) {
      normalized = `${prefix}${normalized.slice(prefix.length * 2)}`
    }
    return normalized
  }

  const currentIframePath = () => `${window.location.pathname}${window.location.search}${window.location.hash}`

  const notifyParentNavigation = () => {
    if (!window.parent || window.parent === window) return
    try {
      window.parent.postMessage({ type: NAV_MESSAGE_TYPE, iframePath: currentIframePath() }, '*')
    } catch (_) {
      // ignore
    }
  }

  const rewriteUrl = (url) => {
    if (typeof url !== 'string') return url
    if (!url || isHashOnly(url) || SPECIAL_SCHEME.test(url)) return url
    if (url.startsWith('/_proxy/')) return normalizeProxiedPath(url)
    if (url.startsWith('/')) return normalizeProxiedPath(`/_proxy/${PROXY_HOST}${url}`)
    try {
      const parsed = new URL(url, window.location.href)
      const proxiedPath = normalizeProxiedPath(`/_proxy/${parsed.host}${parsed.pathname}${parsed.search}${parsed.hash}`)

      if (parsed.pathname.startsWith('/_proxy/')) {
        return normalizeProxiedPath(`${parsed.pathname}${parsed.search}${parsed.hash}`)
      }

      if (parsed.host === window.__hostingSite) return url

      return proxiedPath
    } catch {
      return url
    }
  }

  // =========================== Navigation ====================================
  //
  document.addEventListener('click', (event) => {
    const link = event.target.closest('a')
    if (!link) return

    if (event.defaultPrevented) return
    if (event.button !== 0) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (link.target && link.target !== '_self') return
    if (link.hasAttribute('download')) return

    const raw = link.getAttribute('href')
    if (!raw || isHashOnly(raw) || SPECIAL_SCHEME.test(raw)) return

    const url = rewriteUrl(raw)
    if (!url || url === raw) return

    event.preventDefault()
    window.location.href = url
  }, true)

  document.addEventListener('submit', (event) => {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return

    const raw = form.getAttribute('action') || ''
    const url = rewriteUrl(raw)

    if (!url || url === raw) return

    event.preventDefault()
    form.setAttribute('action', url)
    event.target.submit()
  }, true)

  const _pushState = history.pushState
  const _replaceState = history.replaceState
  history.pushState = function (...args) {
    const result = _pushState.apply(this, args)
    notifyParentNavigation()
    return result
  }
  history.replaceState = function (...args) {
    const result = _replaceState.apply(this, args)
    notifyParentNavigation()
    return result
  }

  window.addEventListener('popstate', notifyParentNavigation)
  window.addEventListener('hashchange', notifyParentNavigation)
  window.addEventListener('load', notifyParentNavigation)

  //document.addEventListener('submit', (event) => {
  //  event.preventDefault()
  //  const form = event.target
  //  const raw = form.getAttribute('action') || ''
  //  const url = raw.startsWith('/') ? `/_proxy/${window.__proxyHost}${raw}` : rewriteUrl(raw)

  //  fetch(url, { method: form.method || 'POST', body: new FormData(form) })
  //    .then(res => res.text())
  //    .then(html => document.documentElement.innerHTML = html)
  //}, true)

  //document.addEventListener('click', (event) => {
  //  const link = event.target.closest('a')
  //  if (!link) return

  //  event.preventDefault()
  //  const raw = link.getAttribute('href')
  //  console.log('[interception] click', { raw })

  //  // Relative URLs need the proxy prefix added
  //  const url = raw.startsWith('/') ? `/_proxy/${window.__proxyHost}${raw}` : rewriteUrl(raw)

  //  fetch(url)
  //    .then(res => res.text())
  //    .then(html => document.documentElement.innerHTML = html)
  //}, true)

  // ============================== fetch ======================================

  window.fetch = (input, init = {}) => {
    const isReq = input instanceof Request
    const url = isReq ? input.url : String(input instanceof URL ? input.href : input)

    const headers = new Headers(init.headers || (isReq ? input.headers : {}))
    headers.set('x-proxy-host', PROXY_HOST)

    const newInit = {
      method: init.method || (isReq ? input.method : 'GET'),
      headers,
      body: 'body' in init ? init.body : (isReq ? input.body : null),
      referrer: `/_proxy/${PROXY_HOST}/`,
    }

    const passthrough = ['credentials', 'mode', 'cache', 'redirect',
      'referrerPolicy', 'integrity', 'keepalive', 'signal']
    for (const key of passthrough) {
      if (key in init) newInit[key] = init[key]
    }

    if (newInit.body instanceof ReadableStream) newInit.duplex = 'half'

    return _fetch.call(window, rewriteUrl(url), newInit).catch((err) => {
      if (err && err.name === 'AbortError') throw err
      return _fetch.call(window, input, init)
    })
  }

  // =========================== XMLHttpRequest ================================

  // Patch open() to stash the original args — we need them to re-open
  // with a rewritten URL since XHR won't let you change it after open()
  XMLHttpRequest.prototype.open = function (method, url, ...rest) {
    this._proxyMeta = { method, url: String(url), openArgs: rest }
    return _xhrOpen.call(this, method, url, ...rest)
  }

  XMLHttpRequest.prototype.send = function (body) {
    const meta = this._proxyMeta
    if (!meta) return _xhrSend.call(this, body)

    const rewritten = rewriteUrl(meta.url)

    // If the URL changed, we have to re-call open() with the new URL
    if (rewritten !== meta.url) {
      _xhrOpen.call(this, meta.method, rewritten, ...meta.openArgs)
    }

    _xhrSetHeader.call(this, 'x-proxy-host', PROXY_HOST)
    return _xhrSend.call(this, body)
  }

  // ============================= WebSocket ===================================

  // Rewrite WebSocket URLs so they go through the proxy.
  // wss://code.cia.net/ws → wss://4000.cia.net/_proxy/code.cia.net/ws
  const rewriteWsUrl = (url) => {
    const raw = typeof url === 'string' ? url : url.toString()
    try {
      const parsed = new URL(raw)
      if (parsed.host === window.__hostingSite) return raw
      // Rewrite wss://upstream/path → wss://proxy/_proxy/upstream/path
      return `${parsed.protocol}//${window.__hostingSite}/_proxy/${parsed.host}${parsed.pathname}${parsed.search}`
    } catch {
      // Relative URL — prefix with proxy host
      if (raw.startsWith('/')) {
        return raw.startsWith('/_proxy/')
          ? `wss://${window.__hostingSite}${raw}`
          : `wss://${window.__hostingSite}/_proxy/${PROXY_HOST}${raw}`
      }
      return raw
    }
  }

  window.WebSocket = function (url, protocols) {
    const rewritten = rewriteWsUrl(url)
    if (protocols !== undefined) return new _WebSocket(rewritten, protocols)
    return new _WebSocket(rewritten)
  }
  window.WebSocket.prototype  = _WebSocket.prototype
  window.WebSocket.CONNECTING = _WebSocket.CONNECTING
  window.WebSocket.OPEN       = _WebSocket.OPEN
  window.WebSocket.CLOSING    = _WebSocket.CLOSING
  window.WebSocket.CLOSED     = _WebSocket.CLOSED

  // ============================ EventSource ==================================

  if (_EventSource) {
    window.EventSource = function (url, dict) {
      const raw = typeof url === 'string' ? url : url.href
      const rewritten = raw.startsWith('/_proxy/') ? raw
        : raw.startsWith('/') ? `/_proxy/${PROXY_HOST}${raw}`
        : rewriteUrl(raw)
      return new _EventSource(rewritten, dict)
    }
    window.EventSource.prototype  = _EventSource.prototype
    window.EventSource.CONNECTING = _EventSource.CONNECTING
    window.EventSource.OPEN       = _EventSource.OPEN
    window.EventSource.CLOSED     = _EventSource.CLOSED
  }

})(window);
