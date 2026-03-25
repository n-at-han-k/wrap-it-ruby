# WebSocket Proxy Architecture

## Overview

The wrap_it_ruby proxy supports transparent WebSocket proxying for upstream services that require persistent connections (e.g. code-server, LiveKit, wetty). WebSocket requests are intercepted at the Protocol::HTTP level — before the Rack adapter — so upgrade headers are preserved.

## Architecture

```
Browser
  │
  │  wss://4000.cia.net/_proxy/code.cia.net/path?token=...
  │
  ▼
Traefik (HTTPS termination)
  │
  │  HTTP/1.1 with Upgrade: websocket
  │
  ▼
proxy_server.rb (Falcon::Server on port 4000)
  │
  ├── WebSocketProxy (Protocol::HTTP middleware)
  │     ├── Detects WebSocket: request.protocol or Upgrade header
  │     ├── Strips /_proxy/{host} prefix from path
  │     ├── Rewrites authority, host, origin for upstream
  │     ├── Removes upgrade/connection headers (client re-adds them)
  │     ├── Sets request.protocol = "websocket" (string, not array)
  │     ├── Forwards to upstream via Async::HTTP::Client (HTTP/1.1)
  │     └── Returns upstream response (101 + streaming body)
  │
  └── Rack adapter → RootRelativeProxy → ScriptInjection → ProxyMiddleware
        (handles normal HTTP requests)
```

## Why Protocol::HTTP Level?

WebSocket proxying **cannot** work at the Rack middleware level because:

1. The Rack adapter strips hop-by-hop headers (`Upgrade`, `Connection`) during request conversion
2. A 101 Switching Protocols response cannot survive the Rack response round-trip — the adapter tries to send it as a chunked body
3. The bidirectional stream after upgrade needs direct access to the underlying connection

The `WebSocketProxy` operates as a `Protocol::HTTP::Middleware`, wrapping the Rack-adapted app. It intercepts WebSocket requests before they reach Rack and returns the upstream response directly.

## Why Falcon::Server?

The proxy must use `Falcon::Server`, not a bare `Async::HTTP::Server`. Falcon properly handles HTTP/1.1 upgrade response relay — when it receives a 101 response from the middleware chain, it correctly upgrades the inbound connection and pipes the streams bidirectionally. A bare `Async::HTTP::Server` tries to write the 101 response as a chunked HTTP body, breaking the pipe.

## Key Implementation Details

### Duplicate Header Bug

The `Async::HTTP::Protocol::HTTP1::Client#call` method calls `write_request(authority, ...)` which writes `host: {authority}` automatically. If `host` is also present in `request.headers`, it gets written twice by `write_headers`. Upstream servers reject duplicate `host` headers with 400 Bad Request.

**Fix:** Always delete `host` from request headers before forwarding. The client adds it from `request.authority`.

### Protocol Field: String, Not Array

The `request.protocol` field controls upgrade behavior in the HTTP/1.1 client. When set, the client calls `write_upgrade_body(protocol)` which writes `connection: upgrade\r\nupgrade: {protocol}\r\n`.

If `protocol` is an array (e.g. `["websocket"]`), Ruby's string interpolation produces `upgrade: ["websocket"]` — invalid. It must be a string: `"websocket"`.

**Fix:** Convert array to string: `request.protocol = request.protocol.first if request.protocol.is_a?(Array)`

### Upgrade/Connection Header Duplication

When `request.protocol` is set, the client's `write_upgrade_body` writes `connection: upgrade` and `upgrade: websocket`. If these headers are also in `request.headers`, they appear twice.

**Fix:** Delete `upgrade` and `connection` from request headers before forwarding. Let `write_upgrade_body` add them cleanly.

### HTTP/1.1 vs HTTP/2

Upstream services behind Traefik typically support WebSocket over HTTP/1.1 (`Upgrade: websocket` → 101) but NOT over HTTP/2 (CONNECT with `:protocol: websocket` → 200). The `Async::HTTP::Client` defaults to HTTP/2 when the upstream supports it.

**Fix:** Force HTTP/1.1 ALPN on the upstream endpoint:

```ruby
Async::HTTP::Endpoint.parse("https://#{host}",
  alpn_protocols: Async::HTTP::Protocol::HTTP11.names
)
```

### WebSocket Detection

WebSocket requests arrive at the proxy in two forms depending on the inbound protocol:

- **HTTP/2** (from Falcon/Traefik): `request.protocol = ["websocket"]`
- **HTTP/1.1** (from Traefik): `Upgrade: websocket` header

The `WebSocketProxy` checks both:

```ruby
def websocket?(request)
  if Array(request.protocol).any? { |p| p.casecmp?("websocket") }
    return true
  end
  if upgrade = request.headers["upgrade"]
    return Array(upgrade).any? { |u| u.casecmp?("websocket") }
  end
  false
end
```

### Client-Side Interception

The `interception.js` script intercepts `new WebSocket(url)` calls in proxied pages and rewrites the URL to go through the proxy:

```
wss://code.cia.net/path → wss://4000.cia.net/_proxy/code.cia.net/path
```

This ensures WebSocket connections from upstream JavaScript go through the proxy rather than directly to the upstream (which would bypass auth and break origin checks).

## Server Setup

The proxy runs as a custom Falcon server (`proxy_server.rb`):

```ruby
# Build Rack app (HTTP proxy middleware chain)
rack_app = Rack::Builder.new do
  use WrapItRuby::Middleware::RootRelativeProxyMiddleware
  use WrapItRuby::Middleware::ScriptInjectionMiddleware
  use WrapItRuby::Middleware::ProxyMiddleware
  run ->(env) { [404, {}, ["Not found"]] }
end.to_app

# Wrap in Falcon's middleware (handles upgrades)
middleware = Falcon::Server.middleware(rack_app)

# Wrap with WebSocket proxy (Protocol::HTTP level)
app = WrapItRuby::Middleware::WebSocketProxy.new(middleware)

# Start Falcon server
endpoint = Async::HTTP::Endpoint.parse("http://0.0.0.0:4000")
Async do
  server = Falcon::Server.new(app, endpoint)
  server.run
  sleep
end
```

## Configuration

Environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `WRAP_IT_PROXY_HOST` | (none) | Proxy hostname for iframe src URLs (e.g. `4000.cia.net`) |
| `WRAP_IT_COOKIE_DOMAIN` | `.cia.net` | Domain for Set-Cookie rewriting |
| `WRAP_IT_AUTH_HOST` | `auth.cia.net` | Authelia host (unused after removing auth exclusion) |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| 400 Bad Request from upstream | Duplicate headers (host, upgrade, connection) | Delete from request.headers before forwarding |
| HTTP2::StreamError: Stream closed | Upstream doesn't support WS over HTTP/2 | Force HTTP/1.1 ALPN on client endpoint |
| WebSocket 1006 (abnormal closure) | Upgrade response not relayed properly | Use Falcon::Server, not Async::HTTP::Server |
| Blank iframe, WS pending, no errors | Stale service worker from failed attempts | Clear site data in browser devtools |
| `upgrade: ["websocket"]` in wire format | request.protocol is array, not string | Convert to string before forwarding |
