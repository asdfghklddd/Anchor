#if os(iOS)
import SwiftUI

extension EnvironmentValues {
    @Entry var openConnectionCard: () -> Void = {}
}
#endif
