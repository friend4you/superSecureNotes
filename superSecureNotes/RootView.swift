import Navigation
import SwiftUI
import VaultSession

struct RootView: View {
    @State private var composition = AppComposition()

    var body: some View {
        NavigationHost(model: composition.navigation.hostModel)
            .task {
                composition.syncRootRoute(
                    isVaultActive: await composition.infrastructure.vaultSession.isActive
                )
                for await isVaultActive in composition.infrastructure.vaultSession.changes {
                    composition.syncRootRoute(isVaultActive: isVaultActive)
                }
            }
    }
}

#Preview {
    RootView()
}
