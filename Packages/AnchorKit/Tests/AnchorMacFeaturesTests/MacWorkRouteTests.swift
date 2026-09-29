#if os(macOS)
import Foundation
import Testing
@testable import AnchorMacFeatures

@Test("Process routes preserve the selected process identity")
func processRouteIdentity() {
    let processID = UUID()

    #expect(MacWorkRoute.process(processID) == .process(processID))
    #expect(MacWorkRoute.timeline != .process(processID))
}
#endif
