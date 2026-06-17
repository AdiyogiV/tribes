import WidgetKit
import SwiftUI

/// Widget bundle for the iPhone/iPad home-screen widgets.
///
/// This is a SEPARATE target from `AuroWatch Widget` (which is watchOS only).
/// Both share the underlying Vedic time calculations but render different
/// widget families (systemSmall/systemMedium vs accessoryCircular/etc).
@main
struct AurogramWidgetBundle: WidgetBundle {
    var body: some Widget {
        VedicDateHomeWidget()
    }
}
