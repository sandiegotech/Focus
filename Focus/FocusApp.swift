import SwiftUI

@main
struct FocusApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(store.selectedActivityColor)
        }
    }
}
