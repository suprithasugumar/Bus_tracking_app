/**
 * Incident & Route Alert Service
 * Manages Cloud Firestore collection: /notifications
 * (Document creation automatically triggers Firebase Cloud Function 'sendRouteNotificationOnCreate' for FCM push)
 */

import { 
  db, 
  collection, 
  addDoc, 
  onSnapshot, 
  serverTimestamp,
  query,
  orderBy,
  limit
} from "./firebase-config.js";

class AlertService {
  constructor() {
    this.alerts = [];
    this.listeners = [];
    this.unsubscribe = null;
  }

  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const notifCol = collection(db, "notifications");
    // Listen to most recent 50 notifications
    this.unsubscribe = onSnapshot(notifCol, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        const data = d.data();
        list.push({
          id: d.id,
          routeId: data.routeId || "General",
          routeName: data.routeName || `Route ${data.routeId || ""}`,
          message: data.message || "",
          type: data.type || "info", // "delay", "breakdown", "info"
          timestamp: data.timestamp || null
        });
      });

      // Sort by timestamp descending
      list.sort((a, b) => {
        const timeA = a.timestamp?.toMillis ? a.timestamp.toMillis() : (a.timestamp?.seconds ? a.timestamp.seconds * 1000 : 0);
        const timeB = b.timestamp?.toMillis ? b.timestamp.toMillis() : (b.timestamp?.seconds ? b.timestamp.seconds * 1000 : 0);
        return timeB - timeA;
      });

      this.alerts = list;
      this.notifyListeners();
    }, (err) => {
      console.error("[AlertService] Firestore listen error:", err);
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
        console.error("[AlertService] Listener error:", e);
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

  /**
   * Post a new route alert
   * Triggers Cloud Function sendRouteNotificationOnCreate automatically!
   */
  async createAlert(routeId, message, type = "info", routeName = "") {
    const notifCol = collection(db, "notifications");
    const docRef = await addDoc(notifCol, {
      routeId: routeId,
      routeName: routeName || `Route ${routeId}`,
      message: message.trim(),
      type: type, // "delay" | "breakdown" | "info"
      timestamp: serverTimestamp(),
      source: "Admin Dashboard"
    });
    return docRef.id;
  }
}

export const alertService = new AlertService();
