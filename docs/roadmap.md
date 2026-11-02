# Roadmap

NetworkTrail is a work in progress. This file shows the plan. The plan can change.

## Done

- Capture of `URLSession` traffic from Debug apps in the iOS Simulator, with one snippet
- A Mac app with a sidebar of apps, a request table, an inspector, search, and Clear
- A Setup Snippet sheet that shows the snippet and the steps

## Next, for the first release

1. Start and Size columns, and a menu to show or hide each column
2. A line in the table that shows a new launch of an app
3. A new inspector with a header, tabs for the response and the request, headers, and query parameters
4. A body viewer for JSON and images
5. Health checks for failed requests, slow requests, and duplicate requests
6. Pause for the live table
7. A first-run screen, and Retry when the Mac app cannot listen
8. Copy a request or a session as text for an AI chat

## Later

- Physical devices over Wi-Fi and USB
- Setup without a snippet
- Support for apps that also contain Pulse
- The time of each phase of a request: DNS, connection, TLS, wait, and download
- HAR export
- WebSocket frames and gRPC

## Not in the first release

- Simulation of network conditions
- Rules that block traffic
- A Network Extension
- Traffic that does not use `URLSession`, for example raw sockets, `NWConnection`, and `WKWebView`
