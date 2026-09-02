/**
 * Real-Time Analytics & Metric Aggregation Service
 * Computes analytics from actual Cloud Firestore documents without fabricating data
 */

export class AnalyticsService {
  /**
   * Aggregate trips per route
   */
  static computeTripsPerRoute(trips, routes) {
    const counts = {};
    routes.forEach(r => { counts[r.routeName || r.routeId] = 0; });
    
    trips.forEach(t => {
      const key = t.routeName || t.routeId || "Other";
      counts[key] = (counts[key] || 0) + 1;
    });

    return Object.keys(counts).map(key => ({
      name: key,
      trips: counts[key]
    })).sort((a, b) => b.trips - a.trips);
  }

  /**
   * Aggregate trips per day
   */
  static computeTripsPerDay(trips) {
    const days = {};
    trips.forEach(t => {
      if (!t.startTime) return;
      let dateObj;
      if (t.startTime.toDate) dateObj = t.startTime.toDate();
      else if (t.startTime.seconds) dateObj = new Date(t.startTime.seconds * 1000);
      else if (t.startTime instanceof Date) dateObj = t.startTime;
      else return;

      const dayStr = dateObj.toLocaleDateString("en-US", { month: "short", day: "numeric" });
      days[dayStr] = (days[dayStr] || 0) + 1;
    });

    const entries = Object.keys(days).map(d => ({ date: d, count: days[d] }));
    return entries.slice(-7); // Last 7 days
  }

  /**
   * Compute average trip duration across completed trips
   */
  static computeAverageDuration(trips) {
    const completed = trips.filter(t => t.isCompleted && t.startTime && t.endTime);
    if (completed.length === 0) return 0;

    let totalMinutes = 0;
    completed.forEach(t => {
      const startMs = t.startTime.toMillis ? t.startTime.toMillis() : (t.startTime.seconds ? t.startTime.seconds * 1000 : 0);
      const endMs = t.endTime.toMillis ? t.endTime.toMillis() : (t.endTime.seconds ? t.endTime.seconds * 1000 : 0);
      if (startMs && endMs && endMs >= startMs) {
        totalMinutes += (endMs - startMs) / 60000;
      }
    });

    return Math.round(totalMinutes / completed.length);
  }

  /**
   * Aggregate incident frequency (Delay, Breakdown, Info)
   */
  static computeAlertDistribution(alerts) {
    let delay = 0;
    let breakdown = 0;
    let info = 0;

    alerts.forEach(a => {
      const type = (a.type || "").toLowerCase();
      if (type === "delay") delay++;
      else if (type === "breakdown") breakdown++;
      else info++;
    });

    return [
      { name: "Delays", count: delay, color: "#F59E0B" },
      { name: "Breakdowns", count: breakdown, color: "#EF4444" },
      { name: "Information", count: info, color: "#3B82F6" }
    ];
  }
}
