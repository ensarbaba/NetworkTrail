# Roadmap

## v1

HTTP(S) through Pulse / `URLSession`. Pulse captures the calls and carries them to the Mac over `_pulse._tcp`. NetworkTrail is the Mac UI (`SessionScreen`, `SessionStore`).

## Later

WebSocket frames and gRPC. Those need their own hooks. Pulse stays the HTTP / `URLSession` path.

## Not in v1

- Network-condition simulation
- Traffic blocking
- Network Extension
- Raw sockets, `NWConnection`, `WKWebView` (anything that is not `URLSession`)
