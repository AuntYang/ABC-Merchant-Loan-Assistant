import SwiftUI

@main
struct ABCMerchantLoanApp: App {
    @StateObject private var dataStore = DataStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
        }
    }
}
