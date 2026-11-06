import Foundation
@testable import NetworkTrailWire
import Testing

struct CapturedErrorTests {
    @Test func titleIsTheMessageOfTheApp() {
        let error = NSError(domain: NSURLErrorDomain, code: -1003, userInfo: [
            NSLocalizedDescriptionKey: "A server with the specified hostname could not be found.",
            NSURLErrorFailingURLStringErrorKey: "https://no-such-host.invalid/",
        ])

        #expect(captured(error).title == "A server with the specified hostname could not be found.")
    }

    @Test func messageKeepsQuotesInsideTheMessage() {
        let error = NSError(domain: "Example", code: 7, userInfo: [NSLocalizedDescriptionKey: #"The key "id" is missing."#])

        #expect(captured(error).title == #"The key "id" is missing."#)
    }

    @Test func urlErrorWithoutAMessageGetsTheNameOfItsCode() {
        // The iOS 27 Simulator sends this: no message, so the text has "(null)".
        let error = CapturedError(
            domain: NSURLErrorDomain,
            code: -1003,
            debugDescription: #"Error Domain=NSURLErrorDomain Code=-1003 "(null)" UserInfo={_kCFStreamErrorCodeKey=8, _kCFStreamErrorDomainKey=12}"#
        )

        #expect(error.message == nil)
        #expect(error.title == "Cannot find host")
    }

    @Test func otherErrorWithoutAMessageIsDomainAndCode() {
        let error = NSError(domain: "Example", code: 7)

        #expect(captured(error).title == "Example error 7")
    }

    @Test func textInAnotherFormatIsTheMessage() {
        let error = CapturedError(domain: "Example", code: 1, debugDescription: "keyNotFound(id)")

        #expect(error.title == "keyNotFound(id)")
    }

    private func captured(_ error: NSError) -> CapturedError {
        CapturedError(domain: error.domain, code: error.code, debugDescription: error.debugDescription)
    }
}
