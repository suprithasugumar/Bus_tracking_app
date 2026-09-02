/**
 * User, Driver & Student Directory Service
 * Queries Cloud Firestore collection: /users
 */

import { 
  db, 
  collection, 
  doc, 
  getDocs, 
  updateDoc, 
  setDoc,
  deleteDoc, 
  onSnapshot,
  serverTimestamp
} from "./firebase-config.js";

class UserService {
  constructor() {
    this.users = [];
    this.listeners = [];
    this.unsubscribe = null;
  }

  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const usersCol = collection(db, "users");
    this.unsubscribe = onSnapshot(usersCol, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        const data = d.data();
        list.push({
          uid: d.id,
          id: d.id,
          name: data.name || "Unnamed User",
          email: data.email || "",
          phone: data.phone || "N/A",
          role: data.role || "Student",
          routeId: data.routeId || "",
          routeName: data.routeName || "",
          createdAt: data.createdAt || null
        });
      });

      this.users = list;
      this.notifyListeners();
    }, (err) => {
      console.error("[UserService] Firestore listen error:", err);
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
        cb(this.users);
      } catch (e) {
        console.error("[UserService] Listener error:", e);
      }
    });
  }

  subscribe(callback) {
    this.listeners.push(callback);
    callback(this.users);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  getDrivers() {
    return this.users.filter((u) => (u.role || "").toLowerCase() === "driver");
  }

  getStudents() {
    return this.users.filter((u) => (u.role || "").toLowerCase() === "student");
  }

  /**
   * Update student preferred route or driver assigned route
   */
  async assignRoute(uid, routeId, routeName) {
    const userRef = doc(db, "users", uid);
    await updateDoc(userRef, {
      routeId: routeId,
      routeName: routeName || ""
    });
  }

  /**
   * Add a new driver / user record
   */
  async createUser(userObj) {
    const uid = userObj.uid || `user_${Date.now()}`;
    const userRef = doc(db, "users", uid);
    await setDoc(userRef, {
      name: userObj.name,
      email: userObj.email,
      phone: userObj.phone || "",
      role: userObj.role || "Driver",
      routeId: userObj.routeId || "",
      createdAt: serverTimestamp()
    }, { merge: true });
    return uid;
  }
}

export const userService = new UserService();
