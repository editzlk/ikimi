import SwiftUI

struct ContentView: View {
    var body: some View {
        WebView()
            .ignoresSafeArea()
            .onAppear {
                // A POS screen should not go to sleep while it is open
                UIApplication.shared.isIdleTimerDisabled = true
            }
    }
}
