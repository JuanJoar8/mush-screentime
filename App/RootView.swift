import SwiftUI
import MushKit

/// Four tabs. Home carries the loop; the rest are depth. Settings lives inside Brain
/// rather than as a fifth tab — it is small and mostly strictness.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Screen = LaunchOptions.screen ?? .home

    enum Screen: String, Hashable {
        case home, blocks, stats, brain, gallery
    }

    var body: some View {
        Group {
            if selection == .gallery {
                StageGalleryView()
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
    }
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
