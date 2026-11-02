# NetworkTrail

> **Work in progress.** NetworkTrail is not ready for daily use. The UI and the setup can change at any time. There is no release yet. To use NetworkTrail, build it from the source code.

NetworkTrail is a Mac app. It shows the `URLSession` traffic of a Debug iOS app in the iOS Simulator.

- NetworkTrail does not use a proxy or a custom certificate.
- You do not add a Swift package to your app, and you do not change its `Info.plist`.
- You paste one snippet into your app one time.

## What works now

- A live table of requests with status, method, host, path, and duration
- An inspector for each request: URL, headers, bodies, and Copy as cURL
- One sidebar row for each app in each Simulator. An app stays in the list after it disconnects.
- Search, and Clear for one app or for all apps

## Requirements

- macOS 14 or later
- Xcode 16 or later
- iOS 17 or later in the Simulator

## Build the Mac app

1. Open `NetworkTrail.xcworkspace` in Xcode.
2. Select the scheme **NetworkTrailMac** and the destination **My Mac**.
3. Build the app (**Product > Build**).
4. Copy `NetworkTrail.app` from the build folder to `/Applications`. The snippet loads a framework from that location.
5. Start `/Applications/NetworkTrail.app`.

To find the build folder, select **Product > Show Build Folder in Finder** in Xcode. The app is in `Products/Debug`.

## Add NetworkTrail to your iOS app

1. In NetworkTrail, click **Setup Snippet** at the bottom of the sidebar.
2. Click **Copy Snippet**.
3. Paste the snippet one time into the launch code of your app, for example `App.init`.
4. Run a Debug build of your app in the iOS Simulator.

The app shows in the NetworkTrail sidebar, and its requests show in the table. This is the snippet:

```swift
#if DEBUG && targetEnvironment(simulator)
Bundle(path: "/Applications/NetworkTrail.app/Contents/Frameworks/NetworkTrailDebug.framework")?.load()
#endif
```

Release builds and builds for devices do not contain this code.

## Try it with DemoApp

The repository contains a sample iOS app, DemoApp. DemoApp contains the snippet.

1. Select the scheme **DemoApp** and an iOS Simulator.
2. Run DemoApp.
3. Tap **GET httpbin**, **POST httpbin**, or **Run all**.

The requests show in NetworkTrail.

## How it works

The snippet loads `NetworkTrailDebug.framework` into your app. The framework uses [Pulse](https://github.com/kean/Pulse) to record the `URLSession` traffic. Then it sends the records to the Mac app on `127.0.0.1:43000`.

An app in the iOS Simulator runs on your Mac. For that app, the address `127.0.0.1` is the Mac. The Mac app listens only on `127.0.0.1`. Other computers cannot connect to it.

## Limits

- NetworkTrail operates only with apps in the iOS Simulator. Physical devices are on the roadmap.
- NetworkTrail shows only `URLSession` traffic.
- `NetworkTrail.app` must be in `/Applications`.
- Only one copy of NetworkTrail can receive traffic at a time. The other copies show an error.
- If your app also contains Pulse, your app can stop with an error.

## Roadmap

Refer to [docs/roadmap.md](docs/roadmap.md).

## License

NetworkTrail uses the MIT License. Refer to [LICENSE](LICENSE). NetworkTrail contains code from Pulse, which also uses the MIT License. Refer to [NOTICE](NOTICE).
