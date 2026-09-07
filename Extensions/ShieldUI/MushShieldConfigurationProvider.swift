import ManagedSettings
import ManagedSettingsUI
import MushKit
import UIKit

/// The block screen.
///
/// This is the *guaranteed* intervention surface — the only one that always appears,
/// with no setup from the user. It is also severely constrained: an icon, a title, a
/// subtitle, two buttons and some colours. No custom views, no animation, no character
/// (docs/01-FEASIBILITY.md L2).
///
/// So the copy has to do the work. It states what happened and offers the way forward,
/// rather than scolding.
class MushShieldConfigurationProvider: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(appName: application.localizedDisplayName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        make(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(appName: webDomain.domain)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        make(appName: webDomain.domain)
    }

    // MARK: -

    private func make(appName: String?) -> ShieldConfiguration {
        let strictness = StrictnessStore().strictness
        let name = appName ?? "This app"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: Palette.shieldBackground,
            icon: Palette.shieldIcon,
            title: ShieldConfiguration.Label(
                text: title(for: strictness),
                color: Palette.title
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle(for: strictness, appName: name),
                color: Palette.subtitle
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: Palette.primaryButtonText
            ),
            primaryButtonBackgroundColor: Palette.primaryButton,
            secondaryButtonLabel: strictness.allowsOverride
                ? ShieldConfiguration.Label(
                    text: "\(strictness.grantMinutes) more minutes",
                    color: Palette.secondaryButtonText
                )
                : nil
        )
    }

    private func title(for strictness: Strictness) -> String {
        switch strictness {
        case .gentle, .standard: "Not right now"
        case .strict, .sealed: "Blocked until the window ends"
        }
    }

    private func subtitle(for strictness: Strictness, appName: String) -> String {
        switch strictness {
        case .gentle:
            "\(appName) is on your list. You can push through, and it will count."
        case .standard:
            "\(appName) is on your list. Getting through costs you something."
        case .strict:
            "\(appName) is on your list. You set this one to hold."
        case .sealed:
            "\(appName) is on your list. Sealed until the window ends."
        }
    }
}

/// Shield colours are duplicated here as literals rather than read from the design
/// tokens, because this extension is woken cold by the system and cannot load the app's
/// asset catalog. Keep them in sync with `brand/brand.json` by hand — it is the one
/// place in the codebase where the token contract cannot be enforced mechanically.
private enum Palette {
    static let shieldBackground = UIColor(red: 0.043, green: 0.051, blue: 0.055, alpha: 1)
    static let title = UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)
    static let subtitle = UIColor(red: 0.66, green: 0.68, blue: 0.67, alpha: 1)
    static let primaryButton = UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)
    static let primaryButtonText = UIColor(red: 0.043, green: 0.051, blue: 0.055, alpha: 1)
    static let secondaryButtonText = UIColor(red: 0.66, green: 0.68, blue: 0.67, alpha: 1)
    static let shieldIcon: UIImage? = nil   // replaced with the character mark in Phase 7
}
