/**
 * Central UI Controller & View Manager
 * Handles DOM rendering, view switching, modals, toasts, charts, and event handlers
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
import { AnalyticsService } from "./analytics-service.js";
import { HealthService } from "./health-service.js";
import { settingsService } from "./settings-service.js";
import { MapController } from "./map-controller.js";

export class UIController {
  constructor() {
    this.currentView = "overview";
    this.fleetMap = null;
    this.overviewMap = null;
    this.selectedBus = null;
    this.editingRoute = null;
    this.searchQuery = "";
  }

  init() {
    this.bindNavigation();
    this.bindModals();
    this.bindForms();
    this.bindSearch();
  }

  /**
   * Show feedback toast
   */
  toast(message, type = "success") {
    const container = document.getElementById("toast-container");
    if (!container) return;

    const toast = document.createElement("div");
    toast.className = `toast ${type}`;
    toast.innerHTML = `<span>${type === 'success' ? '✓' : (type === 'error' ? '✕' : 'ℹ')}</span> <div>${message}</div>`;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = "0";
      toast.style.transform = "translateY(10px)";
      setTimeout(() => toast.remove(), 250);
    }, 3500);
  }

  /**
   * Navigation view switching
   */
  bindNavigation() {
    document.querySelectorAll("[data-nav]").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        const targetView = btn.getAttribute("data-nav");
        this.switchView(targetView);
      });
    });
  }

  switchView(viewId) {
    this.currentView = viewId;

    // Update nav links
    document.querySelectorAll("[data-nav]").forEach((btn) => {
      if (btn.getAttribute("data-nav") === viewId) {
        btn.classList.add("active");
      } else {
        btn.classList.remove("active");
      }
    });

    // Update view panels
    document.querySelectorAll(".view-container").forEach((panel) => {
      if (panel.id === `view-${viewId}`) {
        panel.classList.add("active");
      } else {
        panel.classList.remove("active");
      }
    });

    // Update page title
    const titleEl = document.getElementById("page-title");
    const breadcrumbEl = document.getElementById("page-breadcrumb");
    const titles = {
      overview: { title: "Overview Operations Center", sub: "Dashboard / Overview" },
      tracking: { title: "Live Fleet Telemetry & GPS", sub: "Operations / Live Tracking" },
      buses: { title: "Fleet & Bus Directory", sub: "Main / Buses" },
      drivers: { title: "Driver Management", sub: "Main / Drivers" },
      students: { title: "Student Pass Directory", sub: "Main / Students" },
      routes: { title: "Route & Schedule Management", sub: "Main / Routes" },
      alerts: { title: "Incident & Delay Broadcasts", sub: "Operations / Alerts" },
      announcements: { title: "Campus Announcements", sub: "Operations / Announcements" },
      emergency: { title: "Emergency SOS Command Center", sub: "Operations / Emergency" },
      trips: { title: "Transit Trip History", sub: "Operations / Trips" },
      audit: { title: "Administrative Audit Logs", sub: "Admin / Audit Logs" },
      analytics: { title: "Operations Analytics & Metrics", sub: "Insights / Analytics" },
      health: { title: "System Health Diagnostics", sub: "Insights / Health" },
      settings: { title: "System Parameters & Config", sub: "Admin / Settings" }
    };

    if (titleEl && titles[viewId]) titleEl.textContent = titles[viewId].title;
    if (breadcrumbEl && titles[viewId]) breadcrumbEl.textContent = titles[viewId].sub;

    // Initialize/invalidate maps when switching
    if (viewId === "tracking") {
      if (!this.fleetMap) {
        this.fleetMap = new MapController("tracking-map-el", {
          onBusSelect: (bus) => this.openBusDrawer(bus)
        });
        this.fleetMap.init();
      }
      this.fleetMap.invalidateSize();
      this.fleetMap.updateBuses(busService.buses, this.selectedBus?.id);
    } else if (viewId === "overview") {
      if (!this.overviewMap) {
        this.overviewMap = new MapController("overview-map-el", {
          onBusSelect: (bus) => this.switchView("tracking")
        });
        this.overviewMap.init();
      }
      this.overviewMap.invalidateSize();
      this.overviewMap.updateBuses(busService.buses);
    }

    this.renderCurrentView();
  }

  renderCurrentView() {
    switch (this.currentView) {
      case "overview":
        this.renderOverview();
        break;
      case "tracking":
        this.renderTracking();
        break;
      case "buses":
        this.renderBuses();
        break;
      case "drivers":
        this.renderDrivers();
        break;
      case "students":
        this.renderStudents();
        break;
      case "routes":
        this.renderRoutes();
        break;
      case "alerts":
        this.renderAlerts();
        break;
      case "announcements":
        this.renderAnnouncements();
        break;
      case "emergency":
        this.renderEmergency();
        break;
      case "trips":
        this.renderTrips();
        break;
      case "audit":
        this.renderAuditLogs();
        break;
      case "analytics":
        this.renderAnalytics();
        break;
      case "health":
        this.renderHealth();
        break;
      case "settings":
        this.renderSettings();
        break;
    }
  }

  // ============================================================
  // VIEW: OVERVIEW
  // ============================================================
  renderOverview() {
    const buses = busService.buses;
    const routes = routeService.routes;
    const users = userService.users;
    const drivers = userService.getDrivers();
    const students = userService.getStudents();
    const activeTrips = tripService.getActiveTrips();
    const activeSos = sosService.getActiveEmergencies();
    const alerts = alertService.alerts;
    const announcements = announcementService.announcements;

    const liveBuses = buses.filter(b => b.status === "LIVE").length;
    const offlineBuses = buses.filter(b => b.status === "OFFLINE").length;

    // Update KPI Card Numbers
    const setVal = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setVal("kpi-total-buses", buses.length || routes.length);
    setVal("kpi-active-buses", liveBuses);
    setVal("kpi-offline-buses", offlineBuses);
    setVal("kpi-active-drivers", drivers.length);
    setVal("kpi-total-students", students.length);
    setVal("kpi-total-routes", routes.length);
    setVal("kpi-active-trips", activeTrips.length);
    setVal("kpi-active-sos", activeSos.length);

    // SOS Emergency Alert Banner in Overview
    const sosBanner = document.getElementById("overview-sos-banner");
    if (sosBanner) {
      if (activeSos.length > 0) {
        const topSos = activeSos[0];
        sosBanner.style.display = "block";
        sosBanner.innerHTML = `
          <div style="background:#FEF2F2;border:1px solid #FECACA;border-radius:12px;padding:14px 20px;display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
            <div style="display:flex;align-items:center;gap:14px;">
              <span style="font-size:24px;">🚨</span>
              <div>
                <strong style="color:#DC2626;font-size:14px;">ACTIVE EMERGENCY SOS ALERT</strong>
                <div style="font-size:12.5px;color:#7F1D1D;margin-top:2px;"><strong>${topSos.driverName}</strong> (${topSos.routeId}): ${topSos.message}</div>
              </div>
            </div>
            <button class="btn btn-danger btn-sm" id="btn-goto-sos">Respond Now ➔</button>
          </div>
        `;
        document.getElementById("btn-goto-sos")?.addEventListener("click", () => this.switchView("emergency"));
      } else {
        sosBanner.style.display = "none";
      }
    }

    // Active Trips List
    const tripsListEl = document.getElementById("overview-trips-list");
    if (tripsListEl) {
      if (activeTrips.length === 0) {
        tripsListEl.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:13px;">No trips currently in transit.</div>`;
      } else {
        tripsListEl.innerHTML = activeTrips.slice(0, 5).map(t => `
          <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--border);">
            <div>
              <div style="font-weight:700;font-size:13px;">${t.routeName || t.routeId}</div>
              <div style="font-size:11.5px;color:var(--text-muted);">Driver: ${t.driverName}</div>
            </div>
            <span class="badge badge-live">In Transit</span>
          </div>
        `).join("");
      }
    }

    // Recent Alerts Feed
    const alertsFeedEl = document.getElementById("overview-alerts-feed");
    if (alertsFeedEl) {
      if (alerts.length === 0) {
        alertsFeedEl.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:13px;">No recent alerts.</div>`;
      } else {
        alertsFeedEl.innerHTML = alerts.slice(0, 4).map(a => `
          <div style="display:flex;align-items:flex-start;gap:10px;padding:9px 0;border-bottom:1px solid var(--border);">
            <span style="font-size:16px;">${a.type === 'breakdown' ? '🚨' : (a.type === 'delay' ? '⚠️' : '📢')}</span>
            <div style="flex:1;">
              <div style="font-size:12.5px;font-weight:600;">${a.message}</div>
              <div style="font-size:11px;color:var(--text-muted);margin-top:2px;">${a.routeName || a.routeId}</div>
            </div>
          </div>
        `).join("");
      }
    }

    // Update Overview Map Markers
    if (this.overviewMap) {
      this.overviewMap.updateBuses(buses);
    }
  }

  // ============================================================
  // VIEW: LIVE TRACKING
  // ============================================================
  renderTracking() {
    const buses = busService.buses;
    const routes = routeService.routes;

    // Populate route filter
    const routeFilter = document.getElementById("tracking-route-filter");
    if (routeFilter && routeFilter.options.length <= 1) {
      routes.forEach(r => {
        const opt = document.createElement("option");
        opt.value = r.routeId;
        opt.textContent = r.routeName;
        routeFilter.appendChild(opt);
      });
    }

    // Filter buses
    const selectedRoute = routeFilter ? routeFilter.value : "all";
    const statusFilter = document.getElementById("tracking-status-filter")?.value || "all";
    
    let filtered = buses;
    if (selectedRoute !== "all") {
      filtered = filtered.filter(b => b.routeId === selectedRoute);
    }
    if (statusFilter !== "all") {
      filtered = filtered.filter(b => b.status === statusFilter);
    }

    // Update telemetry summary
    const liveCount = buses.filter(b => b.status === "LIVE").length;
    const staleCount = buses.filter(b => b.status === "STALE").length;
    const offlineCount = buses.filter(b => b.status === "OFFLINE").length;

    const summaryEl = document.getElementById("tracking-summary-badge");
    if (summaryEl) {
      summaryEl.innerHTML = `
        <span style="color:var(--success);font-weight:700;">● ${liveCount} Live</span> &bull; 
        <span style="color:var(--warning);font-weight:700;">● ${staleCount} Stale</span> &bull; 
        <span style="color:var(--text-muted);font-weight:700;">● ${offlineCount} Offline</span>
      `;
    }

    // Update Map
    if (this.fleetMap) {
      this.fleetMap.updateBuses(filtered, this.selectedBus?.id);
    }
  }

  openBusDrawer(bus) {
    this.selectedBus = bus;
    const drawer = document.getElementById("bus-telemetry-drawer");
    if (!drawer) return;

    drawer.style.display = "block";
    drawer.innerHTML = `
      <div style="background:white;border:1px solid var(--border);border-radius:12px;padding:18px;box-shadow:var(--shadow-lg);margin-top:14px;">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
          <div>
            <h4 style="font-size:15px;font-weight:800;">${bus.routeName}</h4>
            <div style="font-size:12px;color:var(--text-muted);">Driver: ${bus.driverName}</div>
          </div>
          <span class="badge badge-${bus.status.toLowerCase()}">${bus.status}</span>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;font-size:12.5px;margin-bottom:12px;">
          <div><strong>Speed:</strong> ${bus.speed} km/h</div>
          <div><strong>Last GPS:</strong> ${bus.lastUpdateText}</div>
          <div><strong>Latitude:</strong> ${bus.latitude.toFixed(4)}</div>
          <div><strong>Longitude:</strong> ${bus.longitude.toFixed(4)}</div>
        </div>
        <div style="display:flex;gap:8px;">
          <button class="btn btn-primary btn-sm" id="btn-focus-bus" style="flex:1;">Focus on Map</button>
          <button class="btn btn-secondary btn-sm" id="btn-close-drawer">Close</button>
        </div>
      </div>
    `;

    document.getElementById("btn-focus-bus")?.addEventListener("click", () => {
      if (this.fleetMap) this.fleetMap.focusBus(bus);
    });
    document.getElementById("btn-close-drawer")?.addEventListener("click", () => {
      drawer.style.display = "none";
      this.selectedBus = null;
      if (this.fleetMap) this.fleetMap.updateBuses(busService.buses, null);
    });
  }

  // ============================================================
  // VIEW: BUSES
  // ============================================================
  renderBuses() {
    const tbody = document.getElementById("buses-tbody");
    if (!tbody) return;

    const buses = busService.buses;
    if (buses.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align:center;padding:30px;color:var(--text-muted);">No bus telemetry records found in Firestore.</td></tr>`;
      return;
    }

    tbody.innerHTML = buses.map(bus => `
      <tr>
        <td>
          <div style="font-weight:700;">🚌 ${bus.routeName}</div>
          <div style="font-size:11px;color:var(--text-muted);font-family:var(--font-mono);">${bus.id}</div>
        </td>
        <td>${bus.driverName}</td>
        <td><span class="badge badge-${bus.status.toLowerCase()}">${bus.status}</span></td>
        <td><strong style="font-family:var(--font-mono);">${bus.speed} km/h</strong></td>
        <td>${bus.latitude.toFixed(4)}, ${bus.longitude.toFixed(4)}</td>
        <td>${bus.lastUpdateText}</td>
        <td>
          <button class="btn btn-secondary btn-sm btn-bus-toggle" data-id="${bus.id}" data-online="${bus.isOnline}">
            ${bus.isOnline ? 'Set Standby' : 'Set Active'}
          </button>
        </td>
      </tr>
    `).join("");

    tbody.querySelectorAll(".btn-bus-toggle").forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = btn.getAttribute("data-id");
        const currentOnline = btn.getAttribute("data-online") === "true";
        await busService.toggleBusStatus(id, !currentOnline);
        await auditService.logAction("BUS_STATUS_TOGGLED", "BUS", id, { isOnline: !currentOnline }, authService.userProfile);
        this.toast(`Bus status updated to ${!currentOnline ? 'Active' : 'Standby'}.`);
      });
    });
  }

  // ============================================================
  // VIEW: DRIVERS
  // ============================================================
  renderDrivers() {
    const tbody = document.getElementById("drivers-tbody");
    if (!tbody) return;

    const drivers = userService.getDrivers();
    if (drivers.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center;padding:30px;color:var(--text-muted);">No drivers found in /users collection.</td></tr>`;
      return;
    }

    tbody.innerHTML = drivers.map(d => `
      <tr>
        <td>
          <div style="font-weight:700;">${d.name}</div>
          <div style="font-size:11.5px;color:var(--text-muted);">${d.email}</div>
        </td>
        <td>${d.phone || 'N/A'}</td>
        <td><span class="badge badge-live">${d.routeName || d.routeId || 'Unassigned'}</span></td>
        <td><span class="badge badge-offline">Driver</span></td>
        <td>
          <button class="btn btn-secondary btn-sm btn-assign-driver-route" data-uid="${d.uid}" data-name="${d.name}">
            Assign Route
          </button>
        </td>
      </tr>
    `).join("");

    tbody.querySelectorAll(".btn-assign-driver-route").forEach(btn => {
      btn.addEventListener("click", () => {
        const uid = btn.getAttribute("data-uid");
        const name = btn.getAttribute("data-name");
        this.openAssignRouteModal(uid, name);
      });
    });
  }

  openAssignRouteModal(uid, name) {
    const select = document.getElementById("modal-assign-route-select");
    const nameEl = document.getElementById("modal-assign-driver-name");
    const uidInput = document.getElementById("modal-assign-user-uid");
    
    if (nameEl) nameEl.textContent = name;
    if (uidInput) uidInput.value = uid;
    if (select) {
      select.innerHTML = routeService.routes.map(r => `<option value="${r.routeId}">${r.routeName}</option>`).join("");
    }

    this.openModal("modal-assign-route");
  }

  // ============================================================
  // VIEW: STUDENTS
  // ============================================================
  renderStudents() {
    const tbody = document.getElementById("students-tbody");
    if (!tbody) return;

    const students = userService.getStudents();
    if (students.length === 0) {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align:center;padding:30px;color:var(--text-muted);">No students registered in /users collection.</td></tr>`;
      return;
    }

    tbody.innerHTML = students.map(s => `
      <tr>
        <td>
          <div style="font-weight:700;">${s.name}</div>
          <div style="font-size:11.5px;color:var(--text-muted);">${s.email}</div>
        </td>
        <td>${s.phone || 'N/A'}</td>
        <td><span class="badge badge-live">${s.routeName || s.routeId || 'Unassigned'}</span></td>
        <td><span class="badge badge-offline">Student</span></td>
        <td>
          <button class="btn btn-secondary btn-sm btn-assign-student-route" data-uid="${s.uid}" data-name="${s.name}">
            Change Route
          </button>
        </td>
      </tr>
    `).join("");

    tbody.querySelectorAll(".btn-assign-student-route").forEach(btn => {
      btn.addEventListener("click", () => {
        const uid = btn.getAttribute("data-uid");
        const name = btn.getAttribute("data-name");
        this.openAssignRouteModal(uid, name);
      });
    });
  }

  // ============================================================
  // VIEW: ROUTES & ROUTE EDITOR
  // ============================================================
  renderRoutes() {
    const tbody = document.getElementById("routes-tbody");
    if (!tbody) return;

    const routes = routeService.routes;
    if (routes.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center;padding:30px;color:var(--text-muted);">No routes configured. Click "Seed Default Routes" to load Chennai routes.</td></tr>`;
      return;
    }

    tbody.innerHTML = routes.map(r => `
      <tr>
        <td><strong style="font-family:var(--font-mono);">${r.routeId}</strong></td>
        <td>
          <div style="font-weight:700;">${r.routeName}</div>
          <div style="font-size:11.5px;color:var(--text-muted);">${r.stops.length} Stops &bull; Start: ${r.stops[0] || 'N/A'} ➔ End: ${r.stops[r.stops.length - 1] || 'N/A'}</div>
        </td>
        <td>${r.schedule?.morning || '7:15 AM'} / ${r.schedule?.evening || '5:15 PM'}</td>
        <td>${r.assignedDriverName || 'Unassigned'}</td>
        <td><span class="badge ${r.isActive ? 'badge-live' : 'badge-offline'}">${r.isActive ? 'Active' : 'Inactive'}</span></td>
        <td>
          <div style="display:flex;gap:6px;align-items:center;">
            <button class="btn btn-secondary btn-sm btn-toggle-route-active" data-id="${r.routeId}" data-active="${r.isActive}">
              ${r.isActive ? 'Deactivate' : 'Activate'}
            </button>
            <button class="btn btn-secondary btn-sm btn-edit-route" data-id="${r.routeId}">Edit</button>
            <button class="btn btn-secondary btn-sm btn-delete-route" data-id="${r.routeId}" style="color:var(--danger);">Delete</button>
          </div>
        </td>
      </tr>
    `).join("");

    tbody.querySelectorAll(".btn-toggle-route-active").forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = btn.getAttribute("data-id");
        const currentActive = btn.getAttribute("data-active") === "true";
        await routeService.toggleActive(id, !currentActive);
        await auditService.logAction("ROUTE_STATUS_TOGGLED", "ROUTE", id, { isActive: !currentActive }, authService.userProfile);
        this.toast(`Route ${id} marked as ${!currentActive ? 'Active' : 'Inactive'}.`);
      });
    });

    tbody.querySelectorAll(".btn-edit-route").forEach(btn => {
      btn.addEventListener("click", () => {
        const id = btn.getAttribute("data-id");
        const route = routes.find(r => r.routeId === id);
        if (route) this.openEditRouteModal(route);
      });
    });

    tbody.querySelectorAll(".btn-delete-route").forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = btn.getAttribute("data-id");
        if (confirm(`Are you sure you want to delete ${id}? This action is irreversible.`)) {
          await routeService.deleteRoute(id);
          await auditService.logAction("ROUTE_DELETED", "ROUTE", id, {}, authService.userProfile);
          this.toast(`Route ${id} deleted.`);
        }
      });
    });
  }

  openEditRouteModal(route) {
    this.editingRoute = JSON.parse(JSON.stringify(route));
    document.getElementById("form-route-id").value = route.routeId;
    document.getElementById("form-route-name").value = route.routeName;
    document.getElementById("form-route-morning").value = route.schedule?.morning || "7:15 AM";
    document.getElementById("form-route-evening").value = route.schedule?.evening || "5:15 PM";
    document.getElementById("form-route-stops").value = route.stops.join(", ");
    
    this.openModal("modal-edit-route");
  }

  // ============================================================
  // VIEW: ALERTS
  // ============================================================
  renderAlerts() {
    const listEl = document.getElementById("alerts-list");
    if (!listEl) return;

    const alerts = alertService.alerts;
    if (alerts.length === 0) {
      listEl.innerHTML = `<div style="padding:40px;text-align:center;color:var(--text-muted);">No incident or delay alerts posted.</div>`;
      return;
    }

    listEl.innerHTML = alerts.map(a => `
      <div class="card" style="margin-bottom:12px;border-left:4px solid ${a.type === 'breakdown' ? '#DC2626' : (a.type === 'delay' ? '#D97706' : '#0265D2')};">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;">
          <div style="display:flex;gap:12px;">
            <span style="font-size:22px;">${a.type === 'breakdown' ? '🚨' : (a.type === 'delay' ? '⚠️' : '📢')}</span>
            <div>
              <div style="font-weight:700;font-size:14.5px;">${a.message}</div>
              <div style="font-size:12px;color:var(--text-muted);margin-top:3px;">
                <strong>Route:</strong> ${a.routeName || a.routeId} &bull; 
                <strong>Severity:</strong> <span class="badge ${a.type === 'breakdown' ? 'badge-sos' : (a.type === 'delay' ? 'badge-stale' : 'badge-live')}">${a.type.toUpperCase()}</span>
              </div>
            </div>
          </div>
          <span style="font-size:12px;color:var(--text-muted);">${busService.getTimeAgoText(a.timestamp)}</span>
        </div>
      </div>
    `).join("");
  }

  // ============================================================
  // VIEW: ANNOUNCEMENTS
  // ============================================================
  renderAnnouncements() {
    const listEl = document.getElementById("announcements-list");
    if (!listEl) return;

    const announcements = announcementService.announcements;
    if (announcements.length === 0) {
      listEl.innerHTML = `<div style="padding:40px;text-align:center;color:var(--text-muted);">No announcements posted yet.</div>`;
      return;
    }

    listEl.innerHTML = announcements.map(ann => `
      <div class="card" style="margin-bottom:12px;">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;">
          <div>
            <div style="font-size:14px;font-weight:600;line-height:1.5;">${ann.message}</div>
            <div style="font-size:12px;color:var(--text-muted);margin-top:6px;">
              <strong>Posted By:</strong> ${ann.postedBy} &bull; <strong>Target:</strong> ${ann.routeId} &bull; ${busService.getTimeAgoText(ann.timestamp)}
            </div>
          </div>
          <button class="btn btn-secondary btn-sm btn-delete-ann" data-id="${ann.id}" style="color:var(--danger);">Delete</button>
        </div>
      </div>
    `).join("");

    listEl.querySelectorAll(".btn-delete-ann").forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = btn.getAttribute("data-id");
        await announcementService.deleteAnnouncement(id);
        await auditService.logAction("ANNOUNCEMENT_DELETED", "ANNOUNCEMENT", id, {}, authService.userProfile);
        this.toast("Announcement deleted.");
      });
    });
  }

  // ============================================================
  // VIEW: EMERGENCY / SOS
  // ============================================================
  renderEmergency() {
    const activeEl = document.getElementById("sos-active-list");
    const historyEl = document.getElementById("sos-history-list");
    const alerts = sosService.alerts;

    const activeSos = alerts.filter(a => (a.status || "ACTIVE").toUpperCase() === "ACTIVE");
    const resolvedSos = alerts.filter(a => (a.status || "ACTIVE").toUpperCase() !== "ACTIVE");

    if (activeEl) {
      if (activeSos.length === 0) {
        activeEl.innerHTML = `
          <div style="background:#ECFDF5;border:1px solid #A7F3D0;border-radius:12px;padding:24px;text-align:center;">
            <div style="font-size:32px;margin-bottom:6px;">🛡️</div>
            <h4 style="color:#065F46;font-size:15px;font-weight:700;">No Active Emergencies</h4>
            <p style="font-size:12.5px;color:#047857;margin-top:4px;">All transit routes operating under standard safety protocol.</p>
          </div>
        `;
      } else {
        activeEl.innerHTML = activeSos.map(sos => `
          <div class="card" style="border:2px solid #DC2626;background:#FEF2F2;margin-bottom:14px;">
            <div style="display:flex;align-items:flex-start;justify-content:space-between;">
              <div style="display:flex;gap:14px;">
                <span style="font-size:28px;">🚨</span>
                <div>
                  <div style="color:#DC2626;font-weight:800;font-size:16px;">CRITICAL SOS EVENT</div>
                  <div style="font-size:14px;font-weight:700;margin-top:4px;">${sos.message}</div>
                  <div style="font-size:12.5px;color:#7F1D1D;margin-top:4px;">
                    <strong>Driver:</strong> ${sos.driverName} &bull; <strong>Route:</strong> ${sos.routeId} &bull; 
                    <strong>Coordinates:</strong> ${sos.latitude ? `${sos.latitude.toFixed(4)}, ${sos.longitude.toFixed(4)}` : 'GPS Acquired'}
                  </div>
                </div>
              </div>
              <div style="display:flex;gap:8px;">
                <button class="btn btn-secondary btn-sm btn-sos-ack" data-id="${sos.id}">Acknowledge</button>
                <button class="btn btn-danger btn-sm btn-sos-resolve" data-id="${sos.id}">Resolve Incident</button>
              </div>
            </div>
          </div>
        `).join("");

        activeEl.querySelectorAll(".btn-sos-ack").forEach(btn => {
          btn.addEventListener("click", async () => {
            const id = btn.getAttribute("data-id");
            await sosService.acknowledgeAlert(id, authService.userProfile?.name);
            await auditService.logAction("SOS_ACKNOWLEDGED", "SOS", id, {}, authService.userProfile);
            this.toast("SOS Alert acknowledged.");
          });
        });

        activeEl.querySelectorAll(".btn-sos-resolve").forEach(btn => {
          btn.addEventListener("click", async () => {
            const id = btn.getAttribute("data-id");
            await sosService.resolveAlert(id, authService.userProfile?.name);
            await auditService.logAction("SOS_RESOLVED", "SOS", id, {}, authService.userProfile);
            this.toast("SOS Alert marked as Resolved.");
          });
        });
      }
    }

    if (historyEl) {
      if (resolvedSos.length === 0) {
        historyEl.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:13px;">No historical emergency logs.</div>`;
      } else {
        historyEl.innerHTML = resolvedSos.map(sos => `
          <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid var(--border);">
            <div>
              <div style="font-weight:700;font-size:13px;">${sos.routeId} &bull; Driver: ${sos.driverName}</div>
              <div style="font-size:12px;color:var(--text-muted);">${sos.message}</div>
            </div>
            <span class="badge badge-offline">${sos.status}</span>
          </div>
        `).join("");
      }
    }
  }

  // ============================================================
  // VIEW: TRIPS
  // ============================================================
  renderTrips() {
    const tbody = document.getElementById("trips-tbody");
    if (!tbody) return;

    const trips = tripService.trips;
    if (trips.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center;padding:30px;color:var(--text-muted);">No trips logged in /trips collection.</td></tr>`;
      return;
    }

    tbody.innerHTML = trips.map(t => `
      <tr>
        <td><strong>${t.routeName || t.routeId}</strong></td>
        <td>${t.driverName}</td>
        <td>${t.durationText}</td>
        <td><span class="badge ${t.isCompleted ? 'badge-offline' : 'badge-live'}">${t.isCompleted ? 'Completed' : 'In Progress'}</span></td>
        <td>${t.startTime ? new Date(t.startTime.seconds ? t.startTime.seconds * 1000 : t.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'N/A'}</td>
        <td>${t.endTime ? new Date(t.endTime.seconds ? t.endTime.seconds * 1000 : t.endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'In Transit'}</td>
      </tr>
    `).join("");
  }

  // ============================================================
  // VIEW: AUDIT LOGS
  // ============================================================
  renderAuditLogs() {
    const tbody = document.getElementById("audit-tbody");
    if (!tbody) return;

    const logs = auditService.logs;
    if (logs.length === 0) {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align:center;padding:30px;color:var(--text-muted);">No administrative audit entries yet.</td></tr>`;
      return;
    }

    tbody.innerHTML = logs.map(l => `
      <tr>
        <td><strong style="font-family:var(--font-mono);font-size:12px;">${l.action}</strong></td>
        <td><span class="badge badge-offline">${l.targetType}</span> ${l.targetId}</td>
        <td>${l.adminName} (${l.adminEmail})</td>
        <td style="font-size:12px;color:var(--text-secondary);">${l.details || '—'}</td>
        <td>${busService.getTimeAgoText(l.timestamp)}</td>
      </tr>
    `).join("");
  }

  // ============================================================
  // VIEW: ANALYTICS
  // ============================================================
  renderAnalytics() {
    const trips = tripService.trips;
    const routes = routeService.routes;
    const alerts = alertService.alerts;

    const tripsPerRoute = AnalyticsService.computeTripsPerRoute(trips, routes);
    const tripsPerDay = AnalyticsService.computeTripsPerDay(trips);
    const avgDuration = AnalyticsService.computeAverageDuration(trips);
    const alertDist = AnalyticsService.computeAlertDistribution(alerts);

    const setVal = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setVal("analytics-total-trips", trips.length);
    setVal("analytics-avg-duration", `${avgDuration || 42} min`);
    setVal("analytics-total-alerts", alerts.length);

    // Render Routes Utilization List
    const routeUtilEl = document.getElementById("analytics-route-utilization");
    if (routeUtilEl) {
      routeUtilEl.innerHTML = tripsPerRoute.slice(0, 5).map(r => `
        <div style="margin-bottom:12px;">
          <div style="display:flex;justify-content:space-between;font-size:12.5px;font-weight:700;margin-bottom:4px;">
            <span>${r.name}</span>
            <span>${r.trips} Trips</span>
          </div>
          <div style="width:100%;height:8px;background:var(--bg-card-subtle);border-radius:4px;overflow:hidden;">
            <div style="width:${Math.min(100, (r.trips / (trips.length || 1)) * 100)}%;height:100%;background:var(--primary);border-radius:4px;"></div>
          </div>
        </div>
      `).join("");
    }
  }

  // ============================================================
  // VIEW: SYSTEM HEALTH
  // ============================================================
  renderHealth() {
    const summary = HealthService.getHealthSummary(busService.buses, sosService.alerts, alertService.alerts);
    const container = document.getElementById("health-metrics-grid");
    if (!container) return;

    container.innerHTML = `
      <div class="card">
        <div style="font-size:12px;font-weight:700;color:var(--text-muted);">FIRESTORE STREAMING</div>
        <div style="font-size:20px;font-weight:800;margin:6px 0;">${summary.firestore.indicator} ${summary.firestore.status}</div>
        <div style="font-size:12px;color:var(--text-secondary);">${summary.firestore.details}</div>
      </div>
      <div class="card">
        <div style="font-size:12px;font-weight:700;color:var(--text-muted);">LIVE GPS TELEMETRY</div>
        <div style="font-size:20px;font-weight:800;margin:6px 0;">${summary.gpsTelemetry.indicator} ${summary.gpsTelemetry.status}</div>
        <div style="font-size:12px;color:var(--text-secondary);">${summary.gpsTelemetry.active} Active &bull; ${summary.gpsTelemetry.stale} Stale &bull; ${summary.gpsTelemetry.offline} Standby</div>
      </div>
      <div class="card">
        <div style="font-size:12px;font-weight:700;color:var(--text-muted);">EMERGENCY SYSTEM</div>
        <div style="font-size:20px;font-weight:800;margin:6px 0;">${summary.emergencySystem.indicator} ${summary.emergencySystem.status}</div>
        <div style="font-size:12px;color:var(--text-secondary);">${summary.emergencySystem.activeCount === 0 ? 'Zero critical issues' : `${summary.emergencySystem.activeCount} active incident`}</div>
      </div>
      <div class="card">
        <div style="font-size:12px;font-weight:700;color:var(--text-muted);">FCM CLOUD FUNCTIONS</div>
        <div style="font-size:20px;font-weight:800;margin:6px 0;">${summary.cloudMessaging.indicator} ${summary.cloudMessaging.status}</div>
        <div style="font-size:12px;color:var(--text-secondary);">${summary.cloudMessaging.details}</div>
      </div>
    `;
  }

  // ============================================================
  // VIEW: SETTINGS
  // ============================================================
  renderSettings() {
    const s = settingsService.settings;
    const staleEl = document.getElementById("setting-stale-sec");
    const offlineEl = document.getElementById("setting-offline-sec");
    const etaEl = document.getElementById("setting-eta-min");

    if (staleEl) staleEl.value = s.staleThresholdSeconds;
    if (offlineEl) offlineEl.value = s.offlineThresholdSeconds;
    if (etaEl) etaEl.value = s.etaMinutesPerStop;
  }

  // ============================================================
  // MODALS & FORMS BINDING
  // ============================================================
  bindModals() {
    document.querySelectorAll(".modal-close, .modal-cancel").forEach(btn => {
      btn.addEventListener("click", () => this.closeAllModals());
    });

    document.querySelectorAll("[data-open-modal]").forEach(btn => {
      btn.addEventListener("click", () => {
        const modalId = btn.getAttribute("data-open-modal");
        this.openModal(modalId);
      });
    });
  }

  openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.add("open");
  }

  closeAllModals() {
    document.querySelectorAll(".modal-backdrop").forEach(m => m.classList.remove("open"));
  }

  bindForms() {
    // Seed Routes Button
    document.getElementById("btn-seed-routes")?.addEventListener("click", async () => {
      if (confirm("Seed all 10 standard Chennai transit routes to Firebase Firestore?")) {
        await routeService.seedRoutes();
        await auditService.logAction("ROUTES_SEEDED", "ROUTES", "BATCH", { count: 10 }, authService.userProfile);
        this.toast("Seeded 10 default Chennai routes to Firestore.");
      }
    });

    // Form: Create New Route
    document.getElementById("form-add-route")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const id = document.getElementById("add-route-id").value.trim();
      const name = document.getElementById("add-route-name").value.trim();
      const morning = document.getElementById("add-route-morning").value.trim();
      const evening = document.getElementById("add-route-evening").value.trim();
      const stopsStr = document.getElementById("add-route-stops").value.trim();

      const stops = stopsStr.split(",").map(s => s.trim()).filter(Boolean);
      
      // Default stop coordinates starting around Chennai
      const stopCoordinates = stops.map((_, i) => ({
        lat: 13.0850 - (i * 0.015),
        lng: 80.2100 + (i * 0.008)
      }));

      await routeService.saveRoute({
        routeId: id,
        routeName: name,
        stops: stops,
        stopCoordinates: stopCoordinates,
        schedule: { morning, evening },
        isActive: true
      });

      await auditService.logAction("ROUTE_CREATED", "ROUTE", id, { name, stopsCount: stops.length }, authService.userProfile);
      this.closeAllModals();
      this.toast(`New route "${name}" created successfully!`);
    });

    // Form: Edit Route
    document.getElementById("form-edit-route")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const id = document.getElementById("form-route-id").value;
      const name = document.getElementById("form-route-name").value;
      const morning = document.getElementById("form-route-morning").value;
      const evening = document.getElementById("form-route-evening").value;
      const stopsStr = document.getElementById("form-route-stops").value;

      const stops = stopsStr.split(",").map(s => s.trim()).filter(Boolean);
      await routeService.saveRoute({
        routeId: id,
        routeName: name,
        stops: stops,
        schedule: { morning, evening },
        isActive: true
      });

      await auditService.logAction("ROUTE_SAVED", "ROUTE", id, { name, stopsCount: stops.length }, authService.userProfile);
      this.closeAllModals();
      this.toast(`Route ${name} saved successfully.`);
    });

    // Form: Assign Route to Driver/Student
    document.getElementById("form-assign-route")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const uid = document.getElementById("modal-assign-user-uid").value;
      const routeId = document.getElementById("modal-assign-route-select").value;
      const route = routeService.routes.find(r => r.routeId === routeId);

      await userService.assignRoute(uid, routeId, route?.routeName);
      await auditService.logAction("USER_ROUTE_ASSIGNED", "USER", uid, { routeId, routeName: route?.routeName }, authService.userProfile);
      this.closeAllModals();
      this.toast(`Route assigned successfully.`);
    });

    // Form: Broadcast Alert
    document.getElementById("form-broadcast-alert")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const routeId = document.getElementById("alert-route-select").value;
      const type = document.getElementById("alert-type-select").value;
      const message = document.getElementById("alert-message-input").value;
      const route = routeService.routes.find(r => r.routeId === routeId);

      await alertService.createAlert(routeId, message, type, route?.routeName);
      await auditService.logAction("ALERT_BROADCASTED", "NOTIFICATION", routeId, { type, message }, authService.userProfile);
      this.closeAllModals();
      this.toast(`Alert broadcasted to students on ${route?.routeName || routeId}.`);
    });

    // Form: Post Announcement
    document.getElementById("form-create-announcement")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const routeId = document.getElementById("ann-route-select").value;
      const message = document.getElementById("ann-message-input").value;

      await announcementService.createAnnouncement(routeId, message, authService.userProfile?.name || "Operations Admin");
      await auditService.logAction("ANNOUNCEMENT_CREATED", "ANNOUNCEMENT", routeId, { message }, authService.userProfile);
      this.closeAllModals();
      this.toast("Campus announcement published.");
    });

    // Form: Settings
    document.getElementById("form-settings")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const stale = parseInt(document.getElementById("setting-stale-sec").value, 10);
      const offline = parseInt(document.getElementById("setting-offline-sec").value, 10);
      const eta = parseInt(document.getElementById("setting-eta-min").value, 10);

      busService.setThresholds(stale, offline);
      await settingsService.saveSettings({
        staleThresholdSeconds: stale,
        offlineThresholdSeconds: offline,
        etaMinutesPerStop: eta
      });

      await auditService.logAction("SETTINGS_SAVED", "SYSTEM", "CONFIG", { stale, offline, eta }, authService.userProfile);
      this.toast("System configuration updated.");
    });
  }

  // ============================================================
  // GLOBAL COMMAND PALETTE SEARCH
  // ============================================================
  bindSearch() {
    const searchBtn = document.getElementById("btn-global-search");
    const modal = document.getElementById("modal-search");
    const searchInput = document.getElementById("global-search-input");
    const resultsContainer = document.getElementById("search-results-list");

    if (searchBtn) {
      searchBtn.addEventListener("click", () => this.openModal("modal-search"));
    }

    document.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        this.openModal("modal-search");
      }
    });

    if (searchInput && resultsContainer) {
      searchInput.addEventListener("input", () => {
        const q = searchInput.value.trim().toLowerCase();
        if (!q) {
          resultsContainer.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:13px;">Type to search buses, drivers, routes, or students...</div>`;
          return;
        }

        const hits = [];
        busService.buses.forEach(b => {
          if (b.routeName.toLowerCase().includes(q) || b.id.toLowerCase().includes(q)) {
            hits.push({ type: "Bus", title: b.routeName, sub: `Driver: ${b.driverName}`, view: "tracking" });
          }
        });

        routeService.routes.forEach(r => {
          if (r.routeName.toLowerCase().includes(q) || r.routeId.toLowerCase().includes(q) || r.stops.some(s => s.toLowerCase().includes(q))) {
            hits.push({ type: "Route", title: r.routeName, sub: `${r.stops.length} Stops`, view: "routes" });
          }
        });

        userService.users.forEach(u => {
          if (u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q)) {
            hits.push({ type: u.role, title: u.name, sub: u.email, view: (u.role || "").toLowerCase() === "driver" ? "drivers" : "students" });
          }
        });

        if (hits.length === 0) {
          resultsContainer.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:13px;">No matching records found.</div>`;
          return;
        }

        resultsContainer.innerHTML = hits.slice(0, 8).map(h => `
          <div class="search-hit-item" data-view="${h.view}" style="padding:10px 14px;border-radius:8px;cursor:pointer;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--border);">
            <div>
              <div style="font-weight:700;font-size:13.5px;">${h.title}</div>
              <div style="font-size:12px;color:var(--text-muted);">${h.sub}</div>
            </div>
            <span class="badge badge-offline">${h.type}</span>
          </div>
        `).join("");

        resultsContainer.querySelectorAll(".search-hit-item").forEach(item => {
          item.addEventListener("click", () => {
            const v = item.getAttribute("data-view");
            this.closeAllModals();
            this.switchView(v);
          });
        });
      });
    }
  }
}

export const uiController = new UIController();
