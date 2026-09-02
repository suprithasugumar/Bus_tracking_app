/**
 * Administrative Audit Trail Service
 * Manages Cloud Firestore collection: /audit_logs
 */

import { 
  db, 
  collection, 
  addDoc, 
  onSnapshot, 
  serverTimestamp 
} from "./firebase-config.js";

class AuditService {
  constructor() {
    this.logs = [];
    this.listeners = [];
    this.unsubscribe = null;
  }

  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const auditCol = collection(db, "audit_logs");
    this.unsubscribe = onSnapshot(auditCol, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        const data = d.data();
        list.push({
          id: d.id,
          adminEmail: data.adminEmail || "admin@transit.org",
          adminName: data.adminName || "Administrator",
          action: data.action || "SYSTEM_EVENT",
          targetType: data.targetType || "GENERAL",
          targetId: data.targetId || "",
          details: data.details || "",
          timestamp: data.timestamp || null
        });
      });

      // Sort newest first
      list.sort((a, b) => {
        const timeA = a.timestamp?.toMillis ? a.timestamp.toMillis() : (a.timestamp?.seconds ? a.timestamp.seconds * 1000 : 0);
        const timeB = b.timestamp?.toMillis ? b.timestamp.toMillis() : (b.timestamp?.seconds ? b.timestamp.seconds * 1000 : 0);
        return timeB - timeA;
      });

      this.logs = list;
      this.notifyListeners();
    }, (err) => {
      console.error("[AuditService] Firestore listen error:", err);
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
        cb(this.logs);
      } catch (e) {
        console.error("[AuditService] Listener error:", e);
      }
    });
  }

  subscribe(callback) {
    this.listeners.push(callback);
    callback(this.logs);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  /**
   * Append-only write for administrative events
   */
  async logAction(action, targetType, targetId, details, adminProfile = null) {
    const auditCol = collection(db, "audit_logs");
    try {
      await addDoc(auditCol, {
        action: action,
        targetType: targetType,
        targetId: targetId || "",
        details: typeof details === "object" ? JSON.stringify(details) : String(details),
        adminEmail: adminProfile?.email || "admin@transit.org",
        adminName: adminProfile?.name || "Administrator",
        timestamp: serverTimestamp()
      });
    } catch (e) {
      console.warn("[AuditService] Failed to write audit log:", e);
    }
  }
}

export const auditService = new AuditService();
