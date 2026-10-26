@testable import NetworkTrailSDK
import Testing

struct AppIdentityTests {
    @Test func appIDIsBundleIDAndSimulatorID() {
        #expect(ClientHello.appID(bundleID: "com.example.Demo", simulatorID: "SIM-A") == "com.example.Demo|SIM-A")
    }

    @Test func otherAppOrOtherSimulatorGetsAnotherID() {
        let demo = ClientHello.appID(bundleID: "com.example.Demo", simulatorID: "SIM-A")
        #expect(demo != ClientHello.appID(bundleID: "com.example.Shop", simulatorID: "SIM-A"))
        #expect(demo != ClientHello.appID(bundleID: "com.example.Demo", simulatorID: "SIM-B"))
    }
}
