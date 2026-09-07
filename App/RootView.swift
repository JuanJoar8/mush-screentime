import SwiftUI
import MushKit

/// Four tabs. Home carries the loop; the rest are depth. Settings lives inside Brain
/// rather than as a fifth tab — it is small and mostly strictness.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            Tab("Home", systemImage: "circle.hexagongrid.fill") {
                HomeView()
            }
            Tab("Blocks", systemImage: "hand.raised.fill") {
                BlocksView()
            }
            Tab("Stats", systemImage: "chart.bar.fill") {
                StatsView()
            }
            Tab("Brain", systemImage: "list.bullet.rectangle") {
                BrainView()
            }
        }
        .tint(model.stage.tint)
        .preferredColorScheme(.dark)
        .background(Token.Color.ground)
    }
}
