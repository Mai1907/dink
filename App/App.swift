import SwiftUI
import SwiftData

@main
struct AppDefinition: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(for: [Pet.self, ScanRecord.self])
  }
}
