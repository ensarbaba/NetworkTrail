# NetworkTrail

Mac app that shows live `URLSession` traffic from a debug iOS app on the same network. Capture and Bonjour transport are [Pulse](https://github.com/kean/Pulse) (MIT). NetworkTrail draws the Mac UI (`SessionScreen` + `SessionStore`).

## Run it

1. Open `NetworkTrail.xcworkspace` in Xcode (macOS 13+, Xcode 15+).
2. Scheme **NetworkTrailMac** → **My Mac**. Keep it running.
3. Scheme **DemoApp** → iOS Simulator (iOS 15+). DEBUG builds call `NetworkTrail.start()`. Tap GET/POST to hit httpbin.

The phone finds the Mac on `_pulse._tcp`. DemoApp in this repo already links the local **NetworkTrailSDK** package.

From the repo root: `swift run NetworkTrailMac`.
