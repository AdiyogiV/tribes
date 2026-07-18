import { DateTime } from "luxon";

export const ORCHESTRATOR_ZONE = "Asia/Kolkata";

/** Calendar facts for the business day in which the nightly jobs run. */
export function orchestratorCalendar(now = DateTime.now()) {
    const local = now.setZone(ORCHESTRATOR_ZONE);
    return {
        date: local.toFormat("yyyy-MM-dd"),
        weekday: local.weekday, // Luxon: Monday=1, Sunday=7
        dayOfMonth: local.day,
        isSunday: local.weekday === 7,
        isMonday: local.weekday === 1,
        isBimonthly: local.day === 1 || local.day === 15,
    };
}
