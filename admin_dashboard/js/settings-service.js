/**
 * System Settings & Operational Parameters Service
 * Manages Cloud Firestore collection: /system_config
 */

import { 
  db, 
  doc, 
  getDoc, 
  setDoc 
} from "./firebase-config.js";

const DEFAULT_SETTINGS = {
  staleThresholdSeconds: 15,
  offlineThresholdSeconds: 60,
  etaMinutesPerStop: 4,
  autoRefreshMap: true,
  enableSoundAlerts: true,
  theme: "light"
};

class SettingsService {
  constructor() {
    this.settings = { ...DEFAULT_SETTINGS };
  }

  async loadSettings() {
    try {
      const docRef = doc(db, "system_config", "general");
      const docSnap = await getDoc(docRef);
      if (docSnap.exists()) {
        this.settings = { ...DEFAULT_SETTINGS, ...docSnap.data() };
      }
    } catch (e) {
      console.warn("[SettingsService] Using local default settings:", e);
    }
    return this.settings;
  }

  async saveSettings(newSettings) {
    this.settings = { ...this.settings, ...newSettings };
    try {
      const docRef = doc(db, "system_config", "general");
      await setDoc(docRef, this.settings, { merge: true });
    } catch (e) {
      console.error("[SettingsService] Error persisting settings:", e);
    }
    return this.settings;
  }
}

export const settingsService = new SettingsService();
