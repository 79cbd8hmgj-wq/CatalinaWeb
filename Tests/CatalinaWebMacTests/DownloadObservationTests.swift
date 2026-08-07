#if os(macOS)
import WebKit
import XCTest
@testable import CatalinaWebApp
@testable import CatalinaWebCore

final class DownloadObservationTests: XCTestCase {
    func testDisplayableResponseIsAllowedWithoutDownloadEvent() {
        let events = RecordingDownloadEventRecorder()
        let delegate = makeDelegate(events: events)
        let response = URLResponse(
            url: URL(string: "https://github.com/")!,
            mimeType: "text/html",
            expectedContentLength: 100,
            textEncodingName: "utf-8"
        )

        XCTAssertEqual(delegate.observeResponseForTesting(response: response, canShowMIMEType: true), .allow)
        XCTAssertTrue(events.events.isEmpty)
    }

    func testNonDisplayableBinaryResponseRecordsDownloadCandidate() {
        let events = RecordingDownloadEventRecorder()
        let delegate = makeDelegate(events: events)
        let url = URL(string: "https://github.com/example/archive.zip")!
        let response = URLResponse(
            url: url,
            mimeType: "application/zip",
            expectedContentLength: 4096,
            textEncodingName: nil
        )

        XCTAssertEqual(delegate.observeResponseForTesting(response: response, canShowMIMEType: false), .allow)
        XCTAssertEqual(events.events, [.downloadCandidate(url: url, mimeType: "application/zip")])
    }

    func testResponseWithoutProvidedMIMEUsesOnlyFoundationObservedMIMEForClassification() {
        let events = RecordingDownloadEventRecorder()
        let delegate = makeDelegate(events: events)
        let url = URL(string: "https://github.com/example/unknown")!
        let response = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: -1,
            textEncodingName: nil
        )

        let observedMIMEType = response.mimeType
        XCTAssertEqual(delegate.observeResponseForTesting(response: response, canShowMIMEType: false), .allow)

        if let observedMIMEType = observedMIMEType {
            XCTAssertEqual(events.events, [.downloadCandidate(url: url, mimeType: observedMIMEType)])
        } else {
            XCTAssertTrue(events.events.isEmpty)
        }
    }

    func testAttachmentContentDispositionRecordsCandidateEvenWhenMIMEIsDisplayable() {
        let events = RecordingDownloadEventRecorder()
        let delegate = makeDelegate(events: events)
        let url = URL(string: "https://github.com/example/readme.txt")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Disposition": "attachment; filename=README.txt", "Content-Type": "text/plain"]
        )!

        XCTAssertEqual(delegate.observeResponseForTesting(response: response, canShowMIMEType: true), .allow)
        XCTAssertEqual(events.events, [.downloadCandidate(url: url, mimeType: "text/plain")])
    }

    private func makeDelegate(events: BrowserEventRecording) -> WebViewNavigationDelegate {
        WebViewNavigationDelegate(
            workspace: .github,
            policy: NavigationPolicy(),
            externalOpener: NoopDownloadOpener(),
            stateStore: InMemoryDownloadStateStore(),
            eventRecorder: events,
            onCommittedURL: { _ in }
        )
    }
}

private final class RecordingDownloadEventRecorder: BrowserEventRecording {
    var events: [BrowserEvent] = []
    func record(_ event: BrowserEvent) { events.append(event) }
}

private final class NoopDownloadOpener: ExternalBrowserOpening {
    func openExternally(_ url: URL) {}
}

private final class InMemoryDownloadStateStore: WorkspaceStateStoring {
    private var state = PersistedWorkspaceState.initial
    func load() -> PersistedWorkspaceState { state }
    func save(_ state: PersistedWorkspaceState) { self.state = state }
}
#endif
