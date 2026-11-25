# Roadmap

NetworkTrail is a work in progress. This file shows the plan. The plan can change.

## Done

- Capture of `URLSession` traffic from Debug apps in the iOS Simulator, with one snippet
- A Mac app with a sidebar of apps, a request table, an inspector, search, and Clear
- A Setup Snippet sheet that shows the snippet and the steps
- Start, Size, and Date columns, and a menu to show or hide each column
- A line in the table that shows a new launch of an app
- An inspector with a header, tabs for the request and the response, headers, and query parameters
- A body viewer for JSON and images
- Health checks for failed requests, slow requests, and duplicate requests
- Pause for the live table
- A first-run screen, and Retry when the Mac app cannot listen
- Copy Request and Response: a request and its response as text
- A Hosts filter that hides the requests to the hosts that you select
- An optional menu bar item, and a start when you log in

## Next, for the first release

1. A local MCP server, so that AI coding agents can read the captured requests

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
