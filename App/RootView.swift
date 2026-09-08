import SwiftUI
import MushKit

/// Four tabs. Home carries the loop; the rest are depth. Settings lives inside Brain
/// rather than as a fifth tab — it is small and mostly strictness.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: Screen = LaunchOptions.screen ?? .home

    /// `fullScreenCover(item:)` needs an Identifiable binding; the model owns the value.
    private var interruptionBinding: Binding<IdentifiedInterruption?> {
        Binding(
            get: { model.pendingInterruption.map(IdentifiedInterruption.init) },
            set: { if $0 == nil { model.resolveInterruption(.turnedBack) } }
        )
    }

    enum Screen: String, Hashable {
        case home, blocks, stats, brain, gallery, setup
    }

    var body: some View {
        Group {
            if selection == .gallery {
                StageGalleryView()
            } else if selection == .setup {
                PathBSetupView()
            } else {
                TabView(selection: $selection) {
                    Tab("Home", systemImage: "drop.fill", value: Screen.home) {
                        HomeView()
                    }
                    Tab("Blocks", systemImage: "hand.raised.fill", value: Screen.blocks) {
                        BlocksView()
                    }
                    Tab("Stats", systemImage: "chart.bar.fill", value: Screen.stats) {
                        StatsView()
                    }
                    Tab("Brain", systemImage: "list.bullet.rectangle", value: Screen.brain) {
                        BrainView()
                    }
                }
            }
        }
        .tint(model.stage.tint)
        .preferredColorScheme(.dark)
        .background(Token.Color.ground)
        // The pause covers everything, including the tab bar. A Shortcuts automation
        // brought the user here mid-tap; giving them somewhere else to go would defeat it.
        .fullScreenCover(item: interruptionBinding) { pending in
            InterruptionView(
                interruption: pending.value,
                stage: model.stage,
                costPerOpen: model.overrideCost
            ) { outcome in
                model.resolveInterruption(outcome)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.checkInterruption() }
        }
        // Above the tabs, below the pause. If a gem lands during an interruption the
        // pause wins: one interruption at a time, and that one was not our idea.
        .overlay {
            if !model.newlyUnlocked.isEmpty && model.pendingInterruption == nil {
                GemUnlockOverlay(
                    gems: model.newlyUnlocked,
                    tint: model.stage.tint
                ) {
                    model.dismissUnlock()
                }
            }
        }
    }
}

/// Wraps the interruption so `fullScreenCover(item:)` can key off it.
struct IdentifiedInterruption: Identifiable {
    let value: PendingInterruption
    init(_ value: PendingInterruption) { self.value = value }
    var id: String { "\(value.appKey).\(value.firedAt.timeIntervalSince1970)" }
}

/// Launch arguments used by CI to capture each screen. Never read in a normal launch.
enum LaunchOptions {
    static var screen: RootView.Screen? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-MushScreen"), index + 1 < args.count else {
            return nil
        }
        return RootView.Screen(rawValue: args[index + 1])
    }
}
