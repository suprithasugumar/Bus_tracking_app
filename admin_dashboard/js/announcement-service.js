/**
 * Campus Broadcast & Announcements Service
 * Manages Cloud Firestore collection: /announcements
 */

import { 
  db, 
  collection, 
  addDoc, 
  deleteDoc, 
  doc, 
  onSnapshot, 
  serverTimestamp 
} from "./firebase-config.js";

class AnnouncementService {
  constructor() {
    this.announcements = [];
    this.listeners = [];
    this.unsubscribe = null;
  }

  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const annCol = collection(db, "announcements");
    this.unsubscribe = onSnapshot(annCol, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        const data = d.data();
        list.push({
          id: d.id,
          routeId: data.routeId || "All Routes",
          message: data.message || "",
          postedBy: data.postedBy || "Fleet Operations Admin",
          timestamp: data.timestamp || null
        });
      });

      // Sort newest first
      list.sort((a, b) => {
        const timeA = a.timestamp?.toMillis ? a.timestamp.toMillis() : (a.timestamp?.seconds ? a.timestamp.seconds * 1000 : 0);
        const timeB = b.timestamp?.toMillis ? b.timestamp.toMillis() : (b.timestamp?.seconds ? b.timestamp.seconds * 1000 : 0);
        return timeB - timeA;
      });

      this.announcements = list;
      this.notifyListeners();
    }, (err) => {
      console.error("[AnnouncementService] Firestore listen error:", err);
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
        cb(this.announcements);
      } catch (e) {
        console.error("[AnnouncementService] Listener error:", e);
      }
    });
  }

  subscribe(callback) {
    this.listeners.push(callback);
    callback(this.announcements);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  /**
   * Post a new announcement
   */
  async createAnnouncement(routeId, message, authorName = "Fleet Operations Admin") {
    const annCol = collection(db, "announcements");
    const docRef = await addDoc(annCol, {
      routeId: routeId || "All Routes",
      message: message.trim(),
      postedBy: authorName,
      timestamp: serverTimestamp()
    });
    return docRef.id;
  }

  /**
   * Delete an announcement
   */
  async deleteAnnouncement(id) {
    const annRef = doc(db, "announcements", id);
    await deleteDoc(annRef);
  }
}

export const announcementService = new AnnouncementService();
