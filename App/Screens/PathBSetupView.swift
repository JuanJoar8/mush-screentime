import SwiftUI
import MushKit

/// How to make this app work without the Family Controls entitlement.
///
/// An app cannot create a Shortcuts personal automation for the user — there is no API,
/// and there is no trick. What it can do is publish App Intents (it does) and then be
/// honest and precise about the six taps. `one sec` has shipped on exactly this for years.
///
/// The screen is written as instructions rather than marketing because a wrong toggle
/// here produces silence, not an error: the automation simply never runs, and usage reads
/// as zero forever.
struct PathBSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    /// The app the user is setting up, used verbatim in the instructions so the steps
    /// read as theirs rather than as a generic template.
    @State private var appName = "Instagram"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                why
                naming
                steps
                second
                limits
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Token.Color.ground)
    }

    private var why: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                InstrumentLabel(title: "Why this exists", value: model.enforcement.label,
                                valueColor: model.enforcement.tint)
                Text("Blocking an app needs an Apple entitlement this build does not have. "
                     + "What works without it: iOS can run a Shortcut the instant an app "
                     + "opens, and that Shortcut can bring you here instead.")
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)
                Text("It is friction, not a lock. You can always continue — and the app "
                     + "counts it when you do.")
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.warn)
            }
        }
    }

    private var naming: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                InstrumentLabel(title: "Which app")
                TextField("App name", text: $appName)
                    .textFieldStyle(.plain)
                    .font(.mushDisplay(24))
                    .foregroundStyle(Token.Color.ink)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.vertical, 8)
                Rectangle().fill(Token.Color.line).frame(height: 1)
                Text("Used in the steps below, and shown on the pause screen.")
                    .font(.system(size: 12))
                    .foregroundStyle(Token.Color.inkDim)
            }
        }
    }

    private var steps: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                InstrumentLabel(title: "The pause", value: "6 steps")

                // Numbered because this genuinely is a sequence — the order is the
                // instruction, not decoration.
                step(1, "Open Shortcuts, go to **Automation**, tap **+**.")
                step(2, "Choose **App**.")
                step(3, "Under *App*, pick **\(appName)**. Leave **Is Opened** ticked.")
                step(4, "Choose **Run Immediately**, and turn **Notify When Run** off.")
                step(5, "Tap **New Blank Automation**, search **Mush**, add **Pause before this app**.")
                step(6, "Set its *App name* to **\(appName)**. Done.")

                PrimaryAction(title: "Open Shortcuts", tint: model.stage.tint) {
                    // Documented URL scheme for the Shortcuts app. If Shortcuts is not
                    // installed the system simply does nothing, which is why the steps
                    // above stand on their own.
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                }
                .padding(.top, 4)
            }
        }
    }

    private var second: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                InstrumentLabel(title: "Measuring", value: "optional")
                Text("A second pair of automations records how long you actually spend, "
                     + "which is what feeds the number on Home.")
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)
                step(1, "Same steps, but add **Log app opened** instead of the pause.")
                step(2, "Make a third automation for **Is Closed**, with **Log app closed**.")
                Text("Without the closing one, a session has no end and the day is marked "
                     + "*partial* — we show a floor, never a guess.")
                    .font(.system(size: 12))
                    .foregroundStyle(Token.Color.inkDim)
            }
        }
    }

    private var limits: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                InstrumentLabel(title: "What this cannot do")
                bullet("Stop the app from opening. It opens; we appear over it.")
                bullet("Work if you turn the automation off. It is yours, in your Shortcuts.")
                bullet("See anything you did not set up. One automation, one app.")
                bullet("Count time while the phone is off or the automation failed to fire. "
                       + "Those days show hollow rather than as zero.")
            }
        }
    }

    private func step(_ number: Int, _ markdown: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.mushData(13))
                .foregroundStyle(model.stage.tint)
                .frame(width: 18, alignment: .trailing)
            Text(.init(markdown))
                .font(.system(size: 14))
                .foregroundStyle(Token.Color.ink)
            Spacer(minLength: 0)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(Token.Color.inkDim)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Token.Color.inkDim)
            Spacer(minLength: 0)
        }
    }
}
