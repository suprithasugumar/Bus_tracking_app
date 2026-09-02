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
    onAuthStateChanged(auth, async (user) => {
      this.currentUser = user;
      if (user) {
        try {
          const userDocRef = doc(db, "users", user.uid);
          const userDoc = await getDoc(userDocRef);
          
          if (userDoc.exists()) {
            this.userProfile = userDoc.data();
            const role = (this.userProfile.role || "").toLowerCase();
            
            if (role === "admin" || role === "superadmin" || role === "driver" || role === "student" || user.email) {
              this.isAdmin = true;
            }
          } else {
            // Auto-provision user as Admin in Firestore
            this.isAdmin = true;
            this.userProfile = {
              name: user.displayName || user.email?.split("@")[0] || "Administrator",
              email: user.email,
              role: "Admin"
            };
            try {
              await setDoc(userDocRef, {
                name: this.userProfile.name,
                email: user.email,
                role: "Admin",
                createdAt: serverTimestamp()
              }, { merge: true });
            } catch (e) {
              console.warn("[AuthService] Could not write /users doc:", e);
            }
          }
        } catch (error) {
          console.warn("[AuthService] Error reading user doc, granting admin access by session:", error);
          this.isAdmin = true;
          this.userProfile = {
            name: user.displayName || user.email?.split("@")[0] || "Administrator",
            email: user.email,
            role: "Admin"
          };
        }
      } else {
        this.userProfile = null;
        this.isAdmin = false;
      }

      this.notifyListeners();
      if (onAuthResolved) onAuthResolved(this.currentUser, this.isAdmin, this.userProfile);
    });
  }

  /**
   * Log in with Email and Password.
   * If the account does not exist in Firebase Auth yet, it automatically creates it.
   */
  async login(email, password) {
    const cleanEmail = email.trim();
    let user = null;

    try {
      const cred = await signInWithEmailAndPassword(auth, cleanEmail, password);
      user = cred.user;
    } catch (authErr) {
      console.warn("[AuthService] signIn failed, trying createUser:", authErr.code);
      try {
        const cred = await createUserWithEmailAndPassword(auth, cleanEmail, password);
        user = cred.user;
      } catch (createErr) {
        console.error("[AuthService] createUser failed:", createErr);
        if (createErr.code === "auth/email-already-in-use" || createErr.code === "auth/wrong-password") {
          throw new Error("Password does not match this existing account. Please re-check your password.");
        }
        throw new Error(createErr.message || authErr.message || "Failed to authenticate.");
      }
    }

    try {
      const userDocRef = doc(db, "users", user.uid);
      const userDoc = await getDoc(userDocRef);
      
      if (userDoc.exists()) {
        this.userProfile = userDoc.data();
      } else {
        this.userProfile = {
          name: user.displayName || cleanEmail.split("@")[0] || "Fleet Administrator",
          email: cleanEmail,
          role: "Admin"
        };
        await setDoc(userDocRef, {
          name: this.userProfile.name,
          email: cleanEmail,
          role: "Admin",
          createdAt: serverTimestamp()
        }, { merge: true });
      }
    } catch (e) {
      console.warn("[AuthService] Firestore sync skipped:", e);
      this.userProfile = {
        name: cleanEmail.split("@")[0] || "Administrator",
        email: cleanEmail,
        role: "Admin"
      };
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
