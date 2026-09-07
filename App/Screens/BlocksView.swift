import SwiftUI
import MushKit

/// What is restricted, and — just as importantly — what kind of restriction it is.
///
/// The copy here changes with the provider, because the two paths do genuinely different
/// things and calling both of them "blocking" would be a lie (docs/09-PATH-B-NO-ENTITLEMENT.md).
struct BlocksView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                capability
                strictness
                limits
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Token.Color.ground)
    }

    private var capability: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                InstrumentLabel(
                    title: "Enforcement",
                    value: model.enforcement.label,
                    valueColor: model.enforcement.tint
                )
                Text(model.enforcement.explanation)
                    .font(.system(size: 13))
                    .foregroundStyle(Token.Color.inkDim)

                if model.authorization != .approved && model.authorization != .unavailable {
                    PrimaryAction(title: "Allow Screen Time access", tint: Token.Color.ink) {
                        Task { await model.requestAuthorization() }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var strictness: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                InstrumentLabel(title: "Strictness", value: model.strictness.title)
                ForEach(Strictness.allCases) { level in
                    Button {
                        model.setStrictness(level)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .strokeBorder(
                                    level == model.strictness ? model.stage.tint : Token.Color.line,
                                    lineWidth: level == model.strictness ? 5 : 1
                                )
                                .frame(width: 16, height: 16)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Token.Color.ink)
                                Text(level.explanation)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Token.Color.inkDim)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Stated at the point of choosing, not buried in a settings footer.
                Text("None of these is a lock. iOS lets you revoke Screen Time access from Settings with one toggle, and nothing we ship can prevent that.")
                    .font(.system(size: 12))
                    .foregroundStyle(Token.Color.warn)
                    .padding(.top, 4)
            }
        }
    }

    private var limits: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                InstrumentLabel(
                    title: "Daily budget",
                    value: "\(model.budgetMinutes) min"
                )
                HStack(spacing: 8) {
                    ForEach([30, 45, 60, 90, 120], id: \.self) { minutes in
                        Button {
                            model.setBudget(minutes)
                        } label: {
                            Pill(
                                text: "\(minutes)",
                                tint: minutes == model.budgetMinutes ? model.stage.tint : Token.Color.inkDim,
                                filled: minutes == model.budgetMinutes
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                Text("Measured in five-minute steps, so the figure is a floor rather than an exact count.")
                    .font(.system(size: 12))
                    .foregroundStyle(Token.Color.inkDim)
            }
        }
    }
}
