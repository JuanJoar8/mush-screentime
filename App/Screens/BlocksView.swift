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
                rules
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

                if !model.authorization.canShield && model.authorization != .unavailable {
                    PrimaryAction(title: "Allow Screen Time access", tint: Token.Color.ink) {
                        Task { await model.requestAuthorization() }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    /// Independent rules, and the one arbitration iOS forces on us.
    ///
    /// The suspension notice is the point of this panel. `.all(except:)` cannot be
    /// softened by another store, so an allowlist genuinely switches the others off —
    /// and a user who is not told that will believe a rule is running when it is not
    /// (docs/08-DECISIONS.md D16).
    private var rules: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                InstrumentLabel(
                    title: "Rules",
                    value: "\(model.ruleResolution.active.count) in force"
                )

                if model.rules.groups.isEmpty {
                    Text("No rules yet. A rule is a set of apps plus when, how long, and how hard.")
                        .font(.system(size: 13))
                        .foregroundStyle(Token.Color.inkDim)
                } else {
                    ForEach(model.rules.groups) { group in
                        ruleRow(group)
                        if group.id != model.rules.groups.last?.id {
                            Rectangle().fill(Token.Color.line).frame(height: 1)
                        }
                    }
                }

                ForEach(model.ruleResolution.suspended.filter { $0.reason == .allowlistExclusive }) { suspension in
                    Text("\(suspension.group.name) is paused while an Only-these rule is running. iOS will not let a second rule reopen anything this one closed.")
                        .font(.system(size: 12))
                        .foregroundStyle(Token.Color.warn)
                }
            }
        }
    }

    @ViewBuilder
    private func ruleRow(_ group: RuleGroup) -> some View {
        let isActive = model.ruleResolution.active.contains { $0.id == group.id }

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    model.toggleRule(group)
                } label: {
                    Circle()
                        .strokeBorder(
                            group.isEnabled ? model.stage.tint : Token.Color.line,
                            lineWidth: group.isEnabled ? 5 : 1
                        )
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                Text(group.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(group.isEnabled ? Token.Color.ink : Token.Color.inkDim)

                Spacer()

                Pill(
                    text: isActive ? "on now" : (group.isEnabled ? "waiting" : "off"),
                    tint: isActive ? model.stage.tint : Token.Color.inkDim,
                    filled: isActive
                )
            }

            HStack(spacing: 8) {
                ForEach(BlockMode.allCases) { mode in
                    Button {
                        model.setRuleMode(group, to: mode)
                    } label: {
                        Pill(
                            text: mode.title,
                            tint: mode == group.mode ? model.stage.tint : Token.Color.inkDim,
                            filled: mode == group.mode
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            Text(ruleSummary(group))
                .font(.system(size: 12))
                .foregroundStyle(Token.Color.inkDim)

            if group.mode.isExclusive {
                Text(group.mode.explanation)
                    .font(.system(size: 12))
                    .foregroundStyle(Token.Color.warn)
            }
        }
        .padding(.vertical, 2)
    }

    private func ruleSummary(_ group: RuleGroup) -> String {
        var parts: [String] = []
        if group.budgetMinutes > 0 { parts.append("\(group.budgetMinutes) min a day") }
        if let limit = group.frequencyLimit { parts.append(limit.summary) }
        if group.windows.isEmpty {
            parts.append("always")
        } else {
            parts.append(group.windows.map(\.name).joined(separator: ", "))
        }
        parts.append(group.strictness.title.lowercased())
        return parts.joined(separator: " · ")
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
