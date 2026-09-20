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
  constructor() {
    this.isDashboardVisible = false;
  }

  init() {
    console.log("[VIT Bus Tracker Admin] Initializing Fleet Control Center...");

    // Global startup error listener to ensure module errors are never silent
    window.addEventListener("error", (e) => {
      const loginError = document.getElementById("login-error-msg");
      if (loginError && !this.isDashboardVisible) {
        loginError.textContent = `Initialization Error: ${e.message}`;
        loginError.style.display = "block";
      }
    });

    // Initialize UI Controller
    try {
      uiController.init();
    } catch (uiErr) {
      console.error("[App] UI Controller initialization error:", uiErr);
    }

    // Bind Login Form Immediately
    const loginForm = document.getElementById("form-admin-login");
    const loginError = document.getElementById("login-error-msg");
    const loginBtn = document.getElementById("btn-login-submit");

    if (loginForm) {
      loginForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        const email = document.getElementById("admin-email-input")?.value || "";
        const pass = document.getElementById("admin-password-input")?.value || "";
        
        if (loginError) loginError.style.display = "none";
        if (loginBtn) {
          loginBtn.textContent = "Authenticating...";
          loginBtn.disabled = true;
        }

        try {
          const res = await authService.login(email, pass);
          this.showDashboard(res.user, res.profile);
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

        if (loginError) loginError.style.display = "none";
        quickDemoBtn.textContent = "Signing In...";
        quickDemoBtn.disabled = true;

        try {
          const res = await authService.login(email, pass);
          this.showDashboard(res.user, res.profile);
          uiController.toast("Admin Authentication Successful!");
        } catch (err) {
          console.error("[QuickDemo] Authentication failed:", err);
          if (loginError) {
            loginError.textContent = err.message || "Authentication failed.";
            loginError.style.display = "block";
          }
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
          this.hideDashboard();
          uiController.toast("Logged out.");
        }
      });
    });

    // Monitor Auth State
    authService.init((user, isAdmin, profile) => {
      if (user && isAdmin) {
        this.showDashboard(user, profile);
      } else {
        this.hideDashboard();
      }
    });
  }

  showDashboard(user, profile) {
    this.isDashboardVisible = true;
    const authScreen = document.getElementById("auth-screen");
    const appShell = document.getElementById("app-shell");

    if (authScreen) authScreen.style.display = "none";
    if (appShell) appShell.style.display = "flex";

    // Update Admin Profile in Sidebar
    const adminNameEl = document.getElementById("sidebar-admin-name");
    const adminRoleEl = document.getElementById("sidebar-admin-role");
    const adminAvatarEl = document.getElementById("sidebar-admin-avatar");

    const displayName = profile?.name || user?.displayName || user?.email?.split("@")[0] || "Administrator";
    const displayRole = profile?.role || "Admin";

    if (adminNameEl) adminNameEl.textContent = displayName;
    if (adminRoleEl) adminRoleEl.textContent = displayRole;
    if (adminAvatarEl) adminAvatarEl.textContent = displayName[0].toUpperCase();

    // Start all real-time Firestore listeners with fault isolation
    this.startRealtimeListeners();
  }

  hideDashboard() {
    this.isDashboardVisible = false;
    const authScreen = document.getElementById("auth-screen");
    const appShell = document.getElementById("app-shell");

    if (authScreen) authScreen.style.display = "flex";
    if (appShell) appShell.style.display = "none";

    // Stop listeners
    this.stopRealtimeListeners();
  }

  startRealtimeListeners() {
    const startListener = (name, fn) => {
      try {
        fn();
      } catch (err) {
        console.error(`[App] Failed to start listener for ${name}:`, err);
      }
    };

    startListener("busService", () => busService.startListening(() => uiController.renderCurrentView()));
    startListener("routeService", () => routeService.startListening(() => uiController.renderCurrentView()));
    startListener("userService", () => userService.startListening(() => uiController.renderCurrentView()));
    startListener("alertService", () => alertService.startListening(() => uiController.renderCurrentView()));
    startListener("announcementService", () => announcementService.startListening(() => uiController.renderCurrentView()));
    startListener("sosService", () => sosService.startListening((alerts) => {
      const activeSos = alerts.filter(a => (a.status || "ACTIVE").toUpperCase() === "ACTIVE");
      const navBadge = document.getElementById("badge-emergency-count");
      if (navBadge) {
        navBadge.textContent = activeSos.length;
        navBadge.style.display = activeSos.length > 0 ? "inline-block" : "none";
      }
      uiController.renderCurrentView();
    }));
    startListener("tripService", () => tripService.startListening(() => uiController.renderCurrentView()));
    startListener("auditService", () => auditService.startListening(() => uiController.renderCurrentView()));

    // Update Live Indicator
    const liveIndicator = document.getElementById("realtime-indicator");
    if (liveIndicator) {
      liveIndicator.className = "realtime-indicator";
      liveIndicator.innerHTML = `<span class="live-dot"></span> LIVE SYNC`;
    }
  }

  stopRealtimeListeners() {
    const stopListener = (name, fn) => {
      try {
        fn();
      } catch (err) {
        console.error(`[App] Failed to stop listener for ${name}:`, err);
      }
    };

    stopListener("busService", () => busService.stopListening());
    stopListener("routeService", () => routeService.stopListening());
    stopListener("userService", () => userService.stopListening());
    stopListener("alertService", () => alertService.stopListening());
    stopListener("announcementService", () => announcementService.stopListening());
    stopListener("sosService", () => sosService.stopListening());
    stopListener("tripService", () => tripService.stopListening());
    stopListener("auditService", () => auditService.stopListening());

    const liveIndicator = document.getElementById("realtime-indicator");
    if (liveIndicator) {
      liveIndicator.className = "realtime-indicator disconnected";
      liveIndicator.innerHTML = `<span class="live-dot"></span> DISCONNECTED`;
    }
  }
}

// Boot application
const app = new App();
window.app = app;
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => app.init());
} else {
  app.init();
}

