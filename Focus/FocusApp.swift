import SwiftUI

@main
struct FocusApp: App {
    @State private var store = Store()

    var body: some Scene {
        #if os(macOS)
        WindowGroup("Focus", id: "main") {
            RootView()
                .environment(store)
                .tint(store.selectedActivityColor)
        }

        MenuBarExtra {
            FocusMenuBarView()
                .environment(store)
                .tint(store.selectedActivityColor)
        } label: {
            FocusMenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            RootView()
                .environment(store)
                .tint(store.selectedActivityColor)
        }
        #endif
    }
}
