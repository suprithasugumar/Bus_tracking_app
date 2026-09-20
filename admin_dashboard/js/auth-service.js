/**
 * Authentication & Role-Based Access Control (RBAC) Service
 */

import { 
  auth, 
  db, 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword,
  signOut, 
  onAuthStateChanged,
  doc, 
  getDoc,
  setDoc,
  serverTimestamp
} from "./firebase-config.js";

class AuthService {
  constructor() {
    this.currentUser = null;
    this.userProfile = null;
    this.isAdmin = false;
    this.authStateListeners = [];
  }

  /**
   * Listen to Firebase Auth state changes and verify admin privileges
   */
  init(onAuthResolved) {
    if (onAuthResolved) {
      this.subscribe(onAuthResolved);
    }

    onAuthStateChanged(auth, async (user) => {
      this.currentUser = user;
      if (user) {
        try {
          const userDocRef = doc(db, "users", user.uid);
          const userDoc = await getDoc(userDocRef);
          
          if (userDoc.exists()) {
            this.userProfile = userDoc.data();
            const role = (this.userProfile.role || "").toLowerCase();
            
            if (role === "admin" || role === "superadmin") {
              this.isAdmin = true;
            } else {
              this.isAdmin = false;
              console.warn(`[AuthService] Authenticated user ${user.uid} role '${this.userProfile.role}' is not Admin.`);
            }
          } else {
            this.userProfile = null;
            this.isAdmin = false;
            console.warn(`[AuthService] No /users record found for ${user.uid}.`);
          }
        } catch (error) {
          console.error("[AuthService] Error reading user doc:", error);
          this.userProfile = null;
          this.isAdmin = false;
        }
      } else {
        this.userProfile = null;
        this.isAdmin = false;
      }

      this.notifyListeners();
    });
  }

  /**
   * Log in with Email and Password.
   * Strictly enforces Admin or Superadmin role from the /users/{uid} document.
   */
  async login(email, password) {
    const cleanEmail = (email || "").trim();
    if (!cleanEmail || !password) {
      throw new Error("Please enter both email and password.");
    }

    let user = null;
    try {
      const cred = await signInWithEmailAndPassword(auth, cleanEmail, password);
      user = cred.user;
    } catch (authErr) {
      console.warn("[AuthService] signIn failed:", authErr.code);
      const code = authErr.code || "";
      if (code === "auth/invalid-credential" || code === "auth/wrong-password" || code === "auth/user-not-found") {
        throw new Error("Invalid email or password. Please verify your credentials.");
      } else if (code === "auth/invalid-email") {
        throw new Error("Please enter a valid email address.");
      } else if (code === "auth/too-many-requests") {
        throw new Error("Access temporarily blocked due to multiple failed sign-in attempts. Please try again later.");
      } else if (code === "auth/network-request-failed") {
        throw new Error("Network error: Unable to connect to Firebase Authentication. Check your connection.");
      }
      throw new Error(authErr.message || "Failed to authenticate.");
    }

    // Role check verification from user document in Firestore
    try {
      const userDocRef = doc(db, "users", user.uid);
      const userDoc = await getDoc(userDocRef);

      if (!userDoc.exists()) {
        await signOut(auth);
        this.currentUser = null;
        this.userProfile = null;
        this.isAdmin = false;
        this.notifyListeners();
        throw new Error("Access Denied: No profile record found in /users for this account.");
      }

      this.userProfile = userDoc.data();
      const role = (this.userProfile.role || "").toLowerCase();

      if (role !== "admin" && role !== "superadmin") {
        await signOut(auth);
        const assignedRole = this.userProfile.role || "Unknown";
        this.currentUser = null;
        this.userProfile = null;
        this.isAdmin = false;
        this.notifyListeners();
        throw new Error(`Access Denied: Account role is '${assignedRole}'. Administrator privileges are required to access this dashboard.`);
      }
    } catch (e) {
      if (e.message && e.message.startsWith("Access Denied")) {
        throw e;
      }
      console.error("[AuthService] Role verification error:", e);
      await signOut(auth);
      this.currentUser = null;
      this.userProfile = null;
      this.isAdmin = false;
      this.notifyListeners();
      throw new Error("Failed to verify administrator role: " + (e.message || "Permission or network error."));
    }

    this.currentUser = user;
    this.isAdmin = true;
    this.notifyListeners();
    return { user, profile: this.userProfile };
  }

  /**
   * Sign out current admin session
   */
  async logout() {
    await signOut(auth);
    this.currentUser = null;
    this.userProfile = null;
    this.isAdmin = false;
    this.notifyListeners();
  }

  subscribe(listener) {
    this.authStateListeners.push(listener);
    listener(this.currentUser, this.isAdmin, this.userProfile);
    return () => {
      this.authStateListeners = this.authStateListeners.filter(l => l !== listener);
    };
  }

  notifyListeners() {
    this.authStateListeners.forEach(listener => {
      try {
        listener(this.currentUser, this.isAdmin, this.userProfile);
      } catch (e) {
        console.error("[AuthService] Listener error:", e);
      }
    });
  }
}

export const authService = new AuthService();
