/**
 * Firebase Web Configuration & Core Service Exports
 * Connects directly to the existing production Firebase project: bustrackingapp-6d421
 */

// Import Firebase SDK modules via official modular CDN (v10.12.2)
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import { 
  getAuth, 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword,
  signOut, 
  onAuthStateChanged,
  setPersistence,
  browserLocalPersistence
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import { 
  getFirestore, 
  collection, 
  doc, 
  getDoc, 
  getDocs, 
  setDoc, 
  addDoc, 
  updateDoc, 
  deleteDoc, 
  query, 
  where, 
  orderBy, 
  limit, 
  onSnapshot, 
  serverTimestamp,
  Timestamp,
  writeBatch
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

// Production Firebase Configuration for bustrackingapp-6d421
export const firebaseConfig = {
  apiKey: "AIzaSyC-SJKacY_NCNuoaa8MYzmQc_1fNKgeyJg",
  authDomain: "bustrackingapp-6d421.firebaseapp.com",
  projectId: "bustrackingapp-6d421",
  storageBucket: "bustrackingapp-6d421.firebasestorage.app",
  messagingSenderId: "211843255527",
  appId: "1:211843255527:web:9e6573c2d259ed34cde642",
  measurementId: "G-X4J4HQWF25"
};

// Initialize Firebase App
export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

// Enable local session persistence
setPersistence(auth, browserLocalPersistence).catch(console.error);

// Re-export common Firestore methods for consistent service usage
export {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  onSnapshot,
  serverTimestamp,
  Timestamp,
  writeBatch
};
