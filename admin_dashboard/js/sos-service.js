/**
 * Emergency / SOS Response Center Service
 * Manages Cloud Firestore collection: /sos_alerts
 */

import { 
  db, 
  collection, 
  doc, 
  updateDoc, 
  addDoc, 
  onSnapshot, 
  serverTimestamp 
} from "./firebase-config.js";

class SosService {
  constructor() {
    this.alerts = [];
    this.listeners = [];
    this.unsubscribe = null;
  }

  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const sosCol = collection(db, "sos_alerts");
    this.unsubscribe = onSnapshot(sosCol, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        const data = d.data();
        list.push({
          id: d.id,
          routeId: data.routeId || "Emergency",
          driverName: data.driverName || "Unknown Driver",
          driverId: data.driverId || "",
          message: data.message || "Emergency SOS Triggered!",
          latitude: typeof data.latitude === "number" ? data.latitude : null,
          longitude: typeof data.longitude === "number" ? data.longitude : null,
          status: data.status || "ACTIVE", // "ACTIVE", "ACKNOWLEDGED", "RESOLVED"
          acknowledgedBy: data.acknowledgedBy || null,
          resolvedBy: data.resolvedBy || null,
          timestamp: data.timestamp || null
        });
      });

      // Sort newest first
      list.sort((a, b) => {
        const timeA = a.timestamp?.toMillis ? a.timestamp.toMillis() : (a.timestamp?.seconds ? a.timestamp.seconds * 1000 : 0);
        const timeB = b.timestamp?.toMillis ? b.timestamp.toMillis() : (b.timestamp?.seconds ? b.timestamp.seconds * 1000 : 0);
        return timeB - timeA;
      });

      this.alerts = list;
      this.notifyListeners();
    }, (err) => {
      console.error("[SosService] Firestore listen error:", err);
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
        cb(this.alerts);
      } catch (e) {
        console.error("[SosService] Listener error:", e);
      }
    });
  }

  subscribe(callback) {
    this.listeners.push(callback);
    callback(this.alerts);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  getActiveEmergencies() {
    return this.alerts.filter((a) => (a.status || "ACTIVE").toUpperCase() === "ACTIVE");
  }

  /**
   * Mark SOS alert as Acknowledged
   */
  async acknowledgeAlert(id, adminName = "Admin") {
    const sosRef = doc(db, "sos_alerts", id);
    await updateDoc(sosRef, {
      status: "ACKNOWLEDGED",
      acknowledgedBy: adminName,
      acknowledgedAt: serverTimestamp()
    });
  }

  /**
   * Mark SOS alert as Resolved
   */
  async resolveAlert(id, adminName = "Admin", notes = "") {
    const sosRef = doc(db, "sos_alerts", id);
    await updateDoc(sosRef, {
      status: "RESOLVED",
      resolvedBy: adminName,
      resolvedAt: serverTimestamp(),
      resolutionNotes: notes
    });
  }

  /**
   * Broadcast a test or simulated emergency
   */
  async triggerSimulatedSos(routeId, driverName, message, lat, lng) {
    const sosCol = collection(db, "sos_alerts");
    return await addDoc(sosCol, {
      routeId: routeId,
      driverName: driverName,
      message: message,
      latitude: lat || 13.0524,
      longitude: lng || 80.2120,
      status: "ACTIVE",
      timestamp: serverTimestamp()
    });
  }
}

export const sosService = new SosService();
