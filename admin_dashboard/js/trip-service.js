/**
 * Trip History & Journey Logging Service
 * Streams Cloud Firestore collection: /trips
 */

import { 
  db, 
  collection, 
  onSnapshot 
} from "./firebase-config.js";

class TripService {
  constructor() {
    this.trips = [];
    this.listeners = [];
    this.unsubscribe = null;
  }

  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const tripCol = collection(db, "trips");
    this.unsubscribe = onSnapshot(tripCol, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        const data = d.data();
        const startTime = data.startTime || null;
        const endTime = data.endTime || null;
        
        let durationText = "In Progress";
        if (startTime && endTime) {
          const startMs = startTime.toMillis ? startTime.toMillis() : (startTime.seconds ? startTime.seconds * 1000 : 0);
          const endMs = endTime.toMillis ? endTime.toMillis() : (endTime.seconds ? endTime.seconds * 1000 : 0);
          if (startMs && endMs && endMs >= startMs) {
            const diffMin = Math.round((endMs - startMs) / 60000);
            if (diffMin < 60) {
              durationText = `${diffMin} min`;
            } else {
              const hr = Math.floor(diffMin / 60);
              const rem = diffMin % 60;
              durationText = `${hr}h ${rem}m`;
            }
          }
        }

        list.push({
          id: d.id,
          driverId: data.driverId || "",
          driverName: data.driverName || "Driver",
          routeId: data.routeId || "",
          routeName: data.routeName || `Route ${data.routeId || ""}`,
          startTime: startTime,
          endTime: endTime,
          durationText: durationText,
          isCompleted: endTime !== null
        });
      });

      // Sort newest first
      list.sort((a, b) => {
        const timeA = a.startTime?.toMillis ? a.startTime.toMillis() : (a.startTime?.seconds ? a.startTime.seconds * 1000 : 0);
        const timeB = b.startTime?.toMillis ? b.startTime.toMillis() : (b.startTime?.seconds ? b.startTime.seconds * 1000 : 0);
        return timeB - timeA;
      });

      this.trips = list;
      this.notifyListeners();
    }, (err) => {
      console.error("[TripService] Firestore listen error:", err);
    });
  }

  stopListening() {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  notifyListeners() {
    this.listeners.forEach((cb) => {
      try {
        cb(this.trips);
      } catch (e) {
        console.error("[TripService] Listener error:", e);
      }
    });
  }

  subscribe(callback) {
    this.listeners.push(callback);
    callback(this.trips);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  getActiveTrips() {
    return this.trips.filter((t) => !t.isCompleted);
  }

  getCompletedTrips() {
    return this.trips.filter((t) => t.isCompleted);
  }
}

export const tripService = new TripService();
