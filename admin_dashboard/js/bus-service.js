/**
 * Live Fleet Telemetry & Bus Location Service
 * Streams real-time positions from Cloud Firestore collection: /bus_location
 */

import { 
  db, 
  collection, 
  onSnapshot,
  doc,
  updateDoc,
  serverTimestamp
} from "./firebase-config.js";

class BusService {
  constructor() {
    this.buses = [];
    this.listeners = [];
    this.unsubscribe = null;
    this.staleThresholdSeconds = 15;
    this.offlineThresholdSeconds = 60;
  }

  /**
   * Set custom stale/offline thresholds in seconds
   */
  setThresholds(staleSec, offlineSec) {
    this.staleThresholdSeconds = staleSec || 15;
    this.offlineThresholdSeconds = offlineSec || 60;
  }

  /**
   * Determine GPS freshness status: "LIVE", "STALE", or "OFFLINE"
   */
  computeStatus(bus) {
    if (!bus.isOnline) return "OFFLINE";
    if (!bus.timestamp) return "STALE";

    const now = Date.now();
    let tsMillis = 0;
    
    if (bus.timestamp.toMillis) {
      tsMillis = bus.timestamp.toMillis();
    } else if (bus.timestamp.seconds) {
      tsMillis = bus.timestamp.seconds * 1000;
    } else if (bus.timestamp instanceof Date) {
      tsMillis = bus.timestamp.getTime();
    } else if (typeof bus.timestamp === "number") {
      tsMillis = bus.timestamp;
    }

    if (!tsMillis) return "STALE";

    const diffSeconds = Math.max(0, (now - tsMillis) / 1000);
    if (diffSeconds < this.staleThresholdSeconds) {
      return "LIVE";
    } else if (diffSeconds <= this.offlineThresholdSeconds) {
      return "STALE";
    } else {
      return "OFFLINE";
    }
  }

  /**
   * Calculate time elapsed text since last update
   */
  getTimeAgoText(timestamp) {
    if (!timestamp) return "Unknown";
    let tsMillis = 0;
    if (timestamp.toMillis) {
      tsMillis = timestamp.toMillis();
    } else if (timestamp.seconds) {
      tsMillis = timestamp.seconds * 1000;
    } else if (timestamp instanceof Date) {
      tsMillis = timestamp.getTime();
    } else if (typeof timestamp === "number") {
      tsMillis = timestamp;
    }
    if (!tsMillis) return "Unknown";

    const sec = Math.max(0, Math.floor((Date.now() - tsMillis) / 1000));
    if (sec < 5) return "Just now";
    if (sec < 60) return `${sec}s ago`;
    const min = Math.floor(sec / 60);
    if (min < 60) return `${min}m ago`;
    const hr = Math.floor(min / 60);
    return `${hr}h ago`;
  }

  /**
   * Start real-time Firestore listener for all bus locations
   */
  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const busCol = collection(db, "bus_location");
    this.unsubscribe = onSnapshot(busCol, (snapshot) => {
      const busList = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        const id = docSnap.id;
        const bus = {
          id: id,
          driverId: id,
          latitude: typeof data.latitude === "number" ? data.latitude : 13.0827,
          longitude: typeof data.longitude === "number" ? data.longitude : 80.2707,
          isOnline: data.isOnline === true,
          routeName: data.routeName || "Unassigned Route",
          routeId: data.routeId || "",
          speed: typeof data.speed === "number" ? Math.round(data.speed) : 0,
          passengerCount: typeof data.passengerCount === "number" ? data.passengerCount : 0,
          timestamp: data.timestamp || null,
          driverName: data.driverName || "Driver " + id.substring(0, 5)
        };
        bus.status = this.computeStatus(bus);
        bus.lastUpdateText = this.getTimeAgoText(bus.timestamp);
        busList.push(bus);
      });

      this.buses = busList;
      this.notifyListeners();
    }, (error) => {
      console.error("[BusService] Firestore listen error:", error);
    });
  }

  /**
   * Stop Firestore snapshot listener
   */
  stopListening() {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  notifyListeners() {
    this.listeners.forEach((cb) => {
      try {
        cb(this.buses);
      } catch (e) {
        console.error("[BusService] Listener callback error:", e);
      }
    });
  }

  subscribe(callback) {
    this.listeners.push(callback);
    callback(this.buses);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  /**
   * Admin control to toggle a bus online/offline status in Firestore
   */
  async toggleBusStatus(driverId, newIsOnline) {
    const busRef = doc(db, "bus_location", driverId);
    await updateDoc(busRef, {
      isOnline: newIsOnline,
      speed: newIsOnline ? 25 : 0,
      timestamp: serverTimestamp()
    });
  }
}

export const busService = new BusService();
