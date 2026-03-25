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

  console.log('[interception]', 'loaded');

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

  const rewriteUrl = (url) => {
    if (typeof url !== 'string') return url
    try {
      const parsed = new URL(url)
      if (parsed.host === window.__hostingSite) return url
      return `/_proxy/${parsed.host}${parsed.pathname}${parsed.search}${parsed.hash}`
    } catch {
      return url
    }
  }

  // =========================== Navigation ====================================
  //
  document.addEventListener('click', (event) => {
    const link = event.target.closest('a')
    if (!link) return

    const raw = link.getAttribute('href')
    const url = raw.startsWith('/_proxy/') ? raw
      : raw.startsWith('/') ? `/_proxy/${window.__proxyHost}${raw}`
      : rewriteUrl(raw)

    event.preventDefault()
    window.location.href = url
  }, true)

  document.addEventListener('submit', (event) => {
    event.preventDefault()
    const form = event.target
    const raw = form.getAttribute('action') || ''
    const url = raw.startsWith('/_proxy/') ? raw
      : raw.startsWith('/') ? `/_proxy/${window.__proxyHost}${raw}`
      : rewriteUrl(raw)

    form.setAttribute('action', url)
    event.target.submit()
  }, true)

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
      console.warn('Proxied fetch failed, retrying without modifications:', err)
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
    console.log('[interception] WebSocket', url, '->', rewritten)
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
