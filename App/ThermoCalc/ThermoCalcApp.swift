import SwiftUI

@main
struct ThermoCalcApp: App {
    @State private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(history)
        }
    }
}
