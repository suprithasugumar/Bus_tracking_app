/// Shared utility for computing stop progression and identifying the next stop.
class StopUtils {
  /// Computes the next unreached stop index along the route.
  /// Next stop = first stop in the route's stop sequence that is not reached
  /// in the current trip's status.
  ///
  /// Returns -1 if all stops are reached, or if there is no active trip.
  static int getNextStopIndex({
    required List<String> stops,
    List<String> completedStops = const [],
    int fallbackCurrentIndex = 0,
    Map<String, dynamic> stopStatuses = const {},
    bool isOnline = true,
  }) {
    if (stops.isEmpty) return -1;
    if (!isOnline) return -1;

    for (int i = 0; i < stops.length; i++) {
      final stopName = stops[i];
      final statusMap = stopStatuses[i.toString()];
      final isReachedInStatuses = statusMap != null &&
          (statusMap is Map && statusMap['status'] == 'reached');
      final isReachedInCompleted = completedStops.contains(stopName);

      if (!isReachedInStatuses && !isReachedInCompleted) {
        return i; // First unreached stop in sequence
      }
    }

    return -1; // All stops reached -> trip completed
  }

  /// Returns true ONLY if every stop in the route is marked reached in the current active trip.
  static bool isTripCompleted({
    required List<String> stops,
    required List<String> completedStops,
    Map<String, dynamic> stopStatuses = const {},
    bool isOnline = true,
  }) {
    if (stops.isEmpty || !isOnline) return false;
    for (int i = 0; i < stops.length; i++) {
      final stopName = stops[i];
      final statusMap = stopStatuses[i.toString()];
      final isReachedInStatuses = statusMap != null &&
          (statusMap is Map && statusMap['status'] == 'reached');
      final isReachedInCompleted = completedStops.contains(stopName);

      if (!isReachedInStatuses && !isReachedInCompleted) {
        return false;
      }
    }
    return true;
  }
}
