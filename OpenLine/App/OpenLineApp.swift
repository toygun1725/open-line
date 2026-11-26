import SwiftUI

@main
struct OpenLineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase
    @State private var directory: LineDirectory?
    @State private var loadError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let directory {
                    OpenLineRoot(directory: directory)
                } else if let loadError {
                    ContentUnavailableView("Open Line", systemImage: "exclamationmark.triangle", description: Text(loadError))
                } else { ProgressView() }
            }
            .task {
                guard directory == nil, loadError == nil else { return }
                do {
                    let hub = try LineDirectory()
                    directory = hub
                    followPendingLink()
                    let profile = hub.profile
                    if await profile.monetization.configure(productID: profile.catalog.iapProductId,
                        fallbackPrice: profile.catalog.iapPriceDisplay.text(for: profile.language)) {
                        profile.applyAllAccessUnlock()
                        hub.sync()
                    }
                } catch { loadError = error.localizedDescription }
            }
            .onOpenURL { OpenLineLink.shared.receive($0); followPendingLink() }
            .onChange(of: OpenLineLink.shared.pending) { _, _ in followPendingLink() }
            .onChange(of: directory?.conversation?.activeStory.id) { _, id in OpenLineLink.shared.foregroundStory = id }
            .onChange(of: directory?.profile.language) { _, _ in directory?.sync(); directory?.scheduleNotifications() }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .background {
                    directory?.prepareForBackground()
                } else if newPhase == .active {
                    directory?.sync()
                    followPendingLink()
                }
            }
        }
    }

    private func followPendingLink() {
        guard let directory, let link = OpenLineLink.shared.pending else { return }
        directory.route(storyID: link.story, sessionID: link.session)
        OpenLineLink.shared.pending = nil
    }
}

private struct OpenLineRoot: View {
    let directory: LineDirectory
    @State private var settings = false
    var body: some View {
        @Bindable var profile = directory.profile
        Group {
            if let line = directory.conversation {
                ChronoChassisView(engine: line, onHome: directory.home, onSettings: { settings = true })
                    .id(line.activeStory.id)
                    .preferredColorScheme(.light)
            } else {
                NightInboxView(directory: directory, onSettings: { settings = true })
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $settings) { SettingsSheetView(profile: profile) }
        .sheet(isPresented: $profile.showPaywallSheet, onDismiss: directory.finishPaywall) {
            AllAccessPaywallSheetView(profile: profile)
        }
    }
}
