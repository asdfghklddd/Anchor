// Role: environment value that opens the pairing card from deep in the view tree.

#if os(iOS)
import SwiftUI

extension EnvironmentValues {
    @Entry var openConnectionCard: () -> Void = {}
}
#endif
