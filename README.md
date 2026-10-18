# NetworkTrail

Mac app that shows live `URLSession` traffic from a debug iOS app on the same network. Capture and Bonjour transport are [Pulse](https://github.com/kean/Pulse) (MIT). NetworkTrail draws the Mac UI (`SessionScreen` + `SessionStore`).

## Run it

1. Open `NetworkTrail.xcworkspace` in Xcode (macOS 14+, Xcode 16+).
2. Scheme **NetworkTrailMac** → **My Mac**. Keep it running.
3. Scheme **DemoApp** → iOS Simulator (iOS 17+). In DEBUG builds, the Simulator snippet in `DemoApp.swift` loads `NetworkTrailDebug.framework`. Tap GET/POST to hit httpbin.

The snippet loads the framework from `/Applications/NetworkTrail.app`, so copy the built `NetworkTrail.app` there first. DemoApp has no Swift package and no Info.plist change for NetworkTrail.
