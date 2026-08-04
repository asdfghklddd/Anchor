import AnchorCore
import AnchorIOSFeatures
import AnchorTransport
import SwiftUI

@main
struct AnchorIOSApp: App {
    private let model: AnchorSessionModel
    private let client: AnchorBonjourClient
    private let proximityScanner: AnchorProximityScanner

    init() {
        let client = AnchorBonjourClient()
        let scanner = AnchorProximityScanner { proximity in
            client.updateProximity(proximity)
        }
        let localRepository = InMemorySessionRepository()
        let repository = LinkedSessionRepository(base: localRepository, client: client)
        self.client = client
        proximityScanner = scanner
        model = AnchorSessionModel(repository: repository, presenceProvider: client)
        scanner.start()
    }

    var body: some Scene {
        WindowGroup {
            AnchorIOSRootView(model: model, linkController: client)
        }
    }
}
