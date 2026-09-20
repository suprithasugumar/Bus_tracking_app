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
  serverTimestamp,
  writeBatch
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
          phone: data.phone || data.rollNumber || "N/A",
          rollNumber: data.rollNumber || "",
          role: data.role || "Student",
          routeId: data.assignedRouteId || data.routeId || "",
          routeName: data.assignedRouteName || data.routeName || "",
          assignedRouteId: data.assignedRouteId || data.routeId || "",
          assignedRouteName: data.assignedRouteName || data.routeName || "",
          selectedStopName: data.selectedStopName || "—",
          selectedStopId: data.selectedStopId || "",
          selectedStopIndex: data.selectedStopIndex,
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
   * Update student preferred route and stop or driver assigned route
   */
  async assignRoute(uid, routeId, routeName, stopName = "") {
    const userRef = doc(db, "users", uid);
    const payload = {
      routeId: routeId,
      routeName: routeName || "",
      assignedRouteId: routeId,
      assignedRouteName: routeName || "",
      updatedAt: serverTimestamp()
    };
    if (stopName) {
      payload.selectedStopName = stopName;
    }
    await updateDoc(userRef, payload);
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
      assignedRouteId: userObj.routeId || "",
      createdAt: serverTimestamp()
    }, { merge: true });
    return uid;
  }

  /**
   * Batch import students from parsed CSV
   */
  async batchImportStudents(studentsList) {
    if (!studentsList || studentsList.length === 0) return 0;
    const batch = writeBatch(db);

    studentsList.forEach((st) => {
      // Use email or clean ID as document key
      const safeId = st.email ? st.email.replace(/[@.]/g, "_") : `student_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const ref = doc(db, "users", safeId);
      batch.set(ref, {
        name: st.name || "Student",
        email: st.email || "",
        phone: st.phone || "",
        rollNumber: st.rollNumber || "",
        role: "Student",
        routeId: st.routeId || "",
        assignedRouteId: st.routeId || "",
        assignedRouteName: st.routeName || st.routeId || "",
        selectedStopName: st.stopName || "",
        createdAt: serverTimestamp(),
        importedVia: "admin_csv_bulk"
      }, { merge: true });
    });

    await batch.commit();
    return studentsList.length;
  }
}

export const userService = new UserService();

