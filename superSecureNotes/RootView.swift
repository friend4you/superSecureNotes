import CredentialStore
import Navigation
import SwiftUI
import VaultSession

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var composition = AppComposition()

    var body: some View {
        NavigationHost(model: composition.navigation.hostModel)
            .task {
                composition.syncRootRoute(
                    hasLocalSetup: composition.infrastructure.credentialStore.hasLocalSetup,
                    isVaultActive: await composition.infrastructure.vaultSession.isActive
                )
                for await isVaultActive in composition.infrastructure.vaultSession.changes {
                    composition.syncRootRoute(
                        hasLocalSetup: composition.infrastructure.credentialStore.hasLocalSetup,
                        isVaultActive: isVaultActive
                    )
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                composition.handleScenePhase(newPhase)
            }
    }
}

#Preview {
    RootView()
}
