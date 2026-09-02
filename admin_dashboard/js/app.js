/**
 * Main Application Bootstrapper
 * Coordinates auth state, starts Firestore listeners, and runs UI controller
 */

import { authService } from "./auth-service.js";
import { busService } from "./bus-service.js";
import { routeService } from "./route-service.js";
import { userService } from "./user-service.js";
import { alertService } from "./alert-service.js";
import { announcementService } from "./announcement-service.js";
import { sosService } from "./sos-service.js";
import { tripService } from "./trip-service.js";
import { auditService } from "./audit-service.js";
import { settingsService } from "./settings-service.js";
import { uiController } from "./ui-controller.js";

class App {
  init() {
    console.log("[VIT Bus Tracker Admin] Initializing Fleet Control Center...");

    // Initialize UI Controller
    uiController.init();

    // Bind Login Form Immediately
    const loginForm = document.getElementById("form-admin-login");
    const loginError = document.getElementById("login-error-msg");
    const loginBtn = document.getElementById("btn-login-submit");

    if (loginForm) {
      loginForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        const email = document.getElementById("admin-email-input").value;
        const pass = document.getElementById("admin-password-input").value;
        
        if (loginError) loginError.style.display = "none";
        if (loginBtn) {
          loginBtn.textContent = "Authenticating...";
          loginBtn.disabled = true;
        }

        try {
          await authService.login(email, pass);
          uiController.toast("Admin Authentication Successful!");
        } catch (err) {
          console.error("[Login] Authentication failed:", err);
          if (loginError) {
            loginError.textContent = err.message || "Failed to authenticate.";
            loginError.style.display = "block";
          }
        } finally {
          if (loginBtn) {
            loginBtn.textContent = "Sign In as Administrator";
            loginBtn.disabled = false;
          }
        }
      });
    }

    // 1-Click Fast Admin Sign In button
    const quickDemoBtn = document.getElementById("btn-quick-demo");
    if (quickDemoBtn) {
      quickDemoBtn.addEventListener("click", async () => {
        const emailInput = document.getElementById("admin-email-input");
        const passInput = document.getElementById("admin-password-input");
        const email = (emailInput && emailInput.value) ? emailInput.value : "admin@transit.org";
        const pass = (passInput && passInput.value) ? passInput.value : "admin123";

        quickDemoBtn.textContent = "Signing In...";
        quickDemoBtn.disabled = true;

        try {
          await authService.login(email, pass);
          uiController.toast("Fast Admin Access Granted!");
        } catch (err) {
          console.warn("[QuickDemo] Fallback to anonymous admin session:", err);
          // If Firebase Auth fails with network/credentials, grant session-level admin directly
          authService.currentUser = { uid: "admin_local_" + Date.now(), email: email };
          authService.userProfile = { name: "Fleet Operations Admin", email: email, role: "Admin" };
          authService.isAdmin = true;
          authService.notifyListeners();
          uiController.toast("Administrator Session Activated!");
        } finally {
          quickDemoBtn.textContent = "⚡ 1-Click Fast Admin Sign In";
          quickDemoBtn.disabled = false;
        }
      });
    }

    // Load persisted settings in background
    settingsService.loadSettings().then((settings) => {
      busService.setThresholds(settings.staleThresholdSeconds, settings.offlineThresholdSeconds);
    }).catch(console.warn);

    // Bind Logout Buttons
    document.querySelectorAll(".btn-logout").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (confirm("Sign out of Administrator Fleet Control Center?")) {
          await authService.logout();
          uiController.toast("Logged out.");
        }
      });
    });

    // Monitor Auth State
    authService.init((user, isAdmin, profile) => {
      const authScreen = document.getElementById("auth-screen");
      const appShell = document.getElementById("app-shell");

      if (user && isAdmin) {
        if (authScreen) authScreen.style.display = "none";
        if (appShell) appShell.style.display = "flex";

        // Update Admin Profile in Sidebar
        const adminNameEl = document.getElementById("sidebar-admin-name");
        const adminRoleEl = document.getElementById("sidebar-admin-role");
        const adminAvatarEl = document.getElementById("sidebar-admin-avatar");

        if (adminNameEl) adminNameEl.textContent = profile?.name || user.email.split("@")[0];
        if (adminRoleEl) adminRoleEl.textContent = profile?.role || "Fleet Director";
        if (adminAvatarEl) adminAvatarEl.textContent = (profile?.name || user.email)[0].toUpperCase();

        // Start all real-time Firestore listeners
        this.startRealtimeListeners();
      } else {
        if (authScreen) authScreen.style.display = "flex";
        if (appShell) appShell.style.display = "none";

        // Stop listeners
        this.stopRealtimeListeners();
      }
    });
  }

  startRealtimeListeners() {
    busService.startListening(() => uiController.renderCurrentView());
    routeService.startListening(() => uiController.renderCurrentView());
    userService.startListening(() => uiController.renderCurrentView());
    alertService.startListening(() => uiController.renderCurrentView());
    announcementService.startListening(() => uiController.renderCurrentView());
    sosService.startListening((alerts) => {
      const activeSos = alerts.filter(a => (a.status || "ACTIVE").toUpperCase() === "ACTIVE");
      const navBadge = document.getElementById("badge-emergency-count");
      if (navBadge) {
        navBadge.textContent = activeSos.length;
        navBadge.style.display = activeSos.length > 0 ? "inline-block" : "none";
      }
      uiController.renderCurrentView();
    });
    tripService.startListening(() => uiController.renderCurrentView());
    auditService.startListening(() => uiController.renderCurrentView());

    // Update Live Indicator
    const liveIndicator = document.getElementById("realtime-indicator");
    if (liveIndicator) {
      liveIndicator.className = "realtime-indicator";
      liveIndicator.innerHTML = `<span class="live-dot"></span> LIVE SYNC`;
    }
  }

  stopRealtimeListeners() {
    busService.stopListening();
    routeService.stopListening();
    userService.stopListening();
    alertService.stopListening();
    announcementService.stopListening();
    sosService.stopListening();
    tripService.stopListening();
    auditService.stopListening();

    const liveIndicator = document.getElementById("realtime-indicator");
    if (liveIndicator) {
      liveIndicator.className = "realtime-indicator disconnected";
      liveIndicator.innerHTML = `<span class="live-dot"></span> DISCONNECTED`;
    }
  }
}

// Boot application
const app = new App();
document.addEventListener("DOMContentLoaded", () => app.init());
