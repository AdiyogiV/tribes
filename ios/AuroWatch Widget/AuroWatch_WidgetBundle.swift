import WidgetKit
import SwiftUI

@main
struct AuroWatch_WidgetBundle: WidgetBundle {
    var body: some Widget {
        VedicTimeComplication()      // Ghati + Pala + Prahar
        PalaPulseComplication()      // Real-time Pala counter
        DualTimeComplication()       // Western ↔ Vedic side by side
        DoshaClockComplication()     // Current Ayurvedic dosha period
        MuhuratAlertComplication()   // Next auspicious/inauspicious window
        TithiComplication()          // Vedic date (Tithi + Paksha + Month)
    }
}
