import SwiftUI
import SafariServices
import MushKit

/// Turning layer 3 on — the part that is not code (`docs/05-SHORTS-REELS.md`).
///
/// The content blocker ships inside the app and does nothing at all until somebody
/// enables it in Settings, and iOS offers no deep link to that pane. So the panel does
/// the only two honest things available: it says whether the extension is currently on,
/// read from the system rather than guessed, and it tells you exactly where to go.
///
/// **The state is read, never assumed.** A panel that says "enabled" because we shipped
/// the extension would be the same lie as a shield screen that says "blocked" over
/// friction. `SFContentBlockerManager.getStateOfContentBlocker` is the only thing that
/// knows, and when it cannot answer, this says so.
@Observable
@MainActor
final class SafariBlockerModel {
    enum State: Equatable {
        case unknown
        case on
        case off
        /// Asked, and iOS declined to say.
        case unreadable(String)
    }

    private(set) var state: State = .unknown

    /// Derived from the app's own identifier rather than written down, because
    /// project.yml builds it the same way — `$(APP_BUNDLE_ID).blocker`. A literal here
    /// would be correct today and silently wrong the first time the bundle prefix moves,
    /// and the symptom would be a panel that reports "not enabled" forever.
    static var identifier: String {
        (Bundle.main.bundleIdentifier ?? "com.mush.app") + ".blocker"
    }

    func refresh() {
        SFContentBlockerManager.getStateOfContentBlocker(
            withIdentifier: Self.identifier
        ) { blockerState, error in
            // Read the Bool out here. `SFContentBlockerState` is not Sendable, so
            // carrying the object itself across the hop is a data race and Swift 6
            // refuses to build it. A Bool and a String are.
            let enabled = blockerState?.isEnabled
            let message = error?.localizedDescription
            MainActor.assumeIsolated {
                if let enabled {
                    self.state = enabled ? .on : .off
                } else {
                    self.state = .unreadable(message ?? "no answer")
                }
            }
        }
    }

    /// Asks Safari to re-read the rule list. Needed after an update changes the rules —
    /// Safari otherwise keeps serving the list it compiled when the extension was
    /// enabled, which is the Safari-side version of the stale-cache problem
    /// `FeedRuleSet.identifier` is versioned to avoid inside the app.
    func reload() {
        SFContentBlockerManager.reloadContentBlocker(withIdentifier: Self.identifier) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
    }
}

struct SafariBlockerPanel: View {
    @State private var model = SafariBlockerModel()

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                InstrumentLabel(title: "Safari", value: label, valueColor: tint)

                Text("""
                The same rules as Clean Feed, applied everywhere you browse in Safari. \
                It is a content blocker: it hands Safari a list of rules once and then \
                does nothing, so it cannot see what you visit.
                """)
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)

                if model.state != .on {
                    // No deep link exists to the extensions pane, so the instruction is
                    // the path. Naming the steps beats a button that opens the wrong page.
                    Text("Settings › Apps › Safari › Extensions › Feed Quarantine")
                        .font(.mushData(12))
                        .foregroundStyle(Token.Color.ink)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Token.Color.panelRaised,
                            in: RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous)
                        )
                }

                HStack(spacing: 8) {
                    Button("Check again") { model.refresh() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Token.Color.accent)
                    Spacer()
                    if model.state == .on {
                        Button("Reload rules") { model.reload() }
                            .font(.system(size: 13))
                            .foregroundStyle(Token.Color.inkDim)
                    }
                }
            }
        }
        .onAppear { model.refresh() }
    }

    private var label: String {
        switch model.state {
        case .unknown: "Checking…"
        case .on: "On"
        case .off: "Not enabled"
        case .unreadable: "Cannot tell"
        }
    }

    private var tint: Color {
        switch model.state {
        case .on: Token.Color.good
        case .off: Token.Color.warn
        case .unknown, .unreadable: Token.Color.inkDim
        }
    }
}
