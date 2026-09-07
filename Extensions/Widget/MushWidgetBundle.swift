import SwiftUI
import WidgetKit

/// One bundle, two surfaces: the Home Screen creature and the Lock Screen session.
///
/// Neither needs the Family Controls entitlement, which is why this is the part of the
/// product that works today on a free Apple ID (docs/09-PATH-B-NO-ENTITLEMENT.md).
@main
struct MushWidgetBundle: WidgetBundle {
    var body: some Widget {
        BrainWidget()
        FocusLiveActivity()
    }
}
