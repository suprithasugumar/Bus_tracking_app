/**
 * Central UI Controller & View Manager
 * Handles DOM rendering, view switching, modals, toasts, charts, and event handlers
 */

import { authService } from "./auth-service.js";
import { busService } from "./bus-service.js";
import { routeService, DEFAULT_CHENNAI_ROUTES } from "./route-service.js";
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
import { MORNING_ROUTES_DATA } from "./morning-routes-data.js";

const CHENNAI_PRESET_LOCATIONS = [
  { name: "Nathamuni Bus Stop", desc: "Villivakkam, Chennai", lat: 13.1118, lng: 80.2052 },
  { name: "Nathamuni Theatre", desc: "MTH Road, Villivakkam, Chennai", lat: 13.1125, lng: 80.2048 },
  { name: "Nathamuni Street", desc: "T. Nagar, Chennai", lat: 13.0410, lng: 80.2330 },
  { name: "Anna Nagar Tower", desc: "Anna Nagar, Chennai", lat: 13.0850, lng: 80.2101 },
  { name: "Anna Nagar Roundtana", desc: "2nd Avenue, Anna Nagar, Chennai", lat: 13.0855, lng: 80.2185 },
  { name: "Koyambedu CMBT Bus Stand", desc: "Koyambedu, Chennai", lat: 13.0694, lng: 80.1948 },
  { name: "Vadapalani Murugan Temple", desc: "Vadapalani, Chennai", lat: 13.0524, lng: 80.2120 },
  { name: "Vadapalani Bus Terminus", desc: "Arcot Road, Vadapalani, Chennai", lat: 13.0505, lng: 80.2132 },
  { name: "Ashok Nagar (Ashok Pillar)", desc: "Ashok Nagar, Chennai", lat: 13.0358, lng: 80.2172 },
  { name: "Ekkattuthangal Metro", desc: "Jawaharlal Nehru Rd, Chennai", lat: 13.0069, lng: 80.2206 },
  { name: "Guindy Kathipara Junction", desc: "Guindy, Chennai", lat: 12.9916, lng: 80.2209 },
  { name: "Guindy Railway Station / Bus Stand", desc: "Guindy, Chennai", lat: 13.0084, lng: 80.2130 },
  { name: "St. Thomas Mount", desc: "St. Thomas Mount, Chennai", lat: 12.9847, lng: 80.1991 },
  { name: "Pallavaram Bus Stand", desc: "GST Road, Pallavaram, Chennai", lat: 12.9675, lng: 80.1490 },
  { name: "Chromepet Bus Stand", desc: "GST Road, Chromepet, Chennai", lat: 12.9516, lng: 80.1416 },
  { name: "Tambaram Sanatorium", desc: "GST Road, Tambaram, Chennai", lat: 12.9412, lng: 80.1284 },
  { name: "Tambaram Bus Terminus", desc: "Tambaram West, Chennai", lat: 12.9249, lng: 80.1000 },
  { name: "Velachery Vijaya Nagar", desc: "Velachery Bypass Rd, Chennai", lat: 12.9815, lng: 80.2180 },
  { name: "Taramani (Ascendas IT Park)", desc: "Taramani, Chennai", lat: 12.9892, lng: 80.2464 },
  { name: "Perungudi Toll Gate", desc: "OMR, Perungudi, Chennai", lat: 12.9651, lng: 80.2466 },
  { name: "Sholinganallur Junction", desc: "OMR / Medavakkam Link Rd, Chennai", lat: 12.9003, lng: 80.2275 },
  { name: "Navalur (OMR IT Corridor)", desc: "Navalur, Chennai", lat: 12.8465, lng: 80.2268 },
  { name: "Siruseri (SIPCOT IT Park)", desc: "Siruseri, Chennai", lat: 12.8273, lng: 80.2189 },
  { name: "Kelambakkam Junction", desc: "Kelambakkam, Chennai", lat: 12.7915, lng: 80.2205 },
  { name: "VIT Chennai Campus", desc: "Vandalur-Kelambakkam Rd, Chennai", lat: 12.8419815, lng: 80.1549340 },
  { name: "Porur Tollgate / Junction", desc: "Mount-Poonamallee Rd, Porur, Chennai", lat: 13.0382, lng: 80.1565 },
  { name: "Avadi Bus Stand", desc: "Avadi, Chennai", lat: 13.1147, lng: 80.1017 },
  { name: "Perambur Railway Station", desc: "Perambur, Chennai", lat: 13.1112, lng: 80.2415 },
  { name: "Broadway Bus Terminus", desc: "George Town, Chennai", lat: 13.0883, lng: 80.2885 },
  { name: "Chennai Central Railway Station", desc: "Park Town, Chennai", lat: 13.0827, lng: 80.2707 },
  { name: "Chennai Egmore Railway Station", desc: "Egmore, Chennai", lat: 13.0784, lng: 80.2607 },
  { name: "Saidapet Panagal Building", desc: "Saidapet, Chennai", lat: 13.0210, lng: 80.2293 },
  { name: "T. Nagar Bus Terminus", desc: "Panagal Park, T. Nagar, Chennai", lat: 13.0418, lng: 80.2341 },
  { name: "Adyar Depot / Lattice Bridge", desc: "Adyar, Chennai", lat: 13.0064, lng: 80.2575 },
  { name: "Thiruvanmiyur Bus Depot", desc: "Thiruvanmiyur, Chennai", lat: 12.9868, lng: 80.2588 },
  { name: "Medavakkam Koot Road", desc: "Medavakkam, Chennai", lat: 12.9215, lng: 80.1936 },
  { name: "Pallikaranai Bus Stop", desc: "Velachery Main Rd, Pallikaranai, Chennai", lat: 12.9325, lng: 80.2121 },
  { name: "Poonamallee Bus Terminus", desc: "Poonamallee, Chennai", lat: 13.0494, lng: 80.1118 },
  { name: "Iyyappanthangal Depot", desc: "Mount-Poonamallee Rd, Chennai", lat: 13.0435, lng: 80.1382 },
  { name: "Ambattur OT Bus Stand", desc: "Ambattur, Chennai", lat: 13.1143, lng: 80.1548 },
  { name: "Villivakkam Bus Stand", desc: "Villivakkam, Chennai", lat: 13.1090, lng: 80.2070 },
  { name: "Kolathur Retteri Junction", desc: "Kolathur, Chennai", lat: 13.1250, lng: 80.2090 }
];

export class UIController {
  constructor() {
    this.currentView = "overview";
    this.fleetMap = null;
    this.overviewMap = null;
    this.selectedBus = null;
    this.editingRoute = null;
    this.searchQuery = "";
    this.addRouteStops = [];
    this.editRouteStops = [];
  }

  init() {
    this.bindNavigation();
    this.bindModals();
    this.bindForms();
    this.bindSearch();
    this.bindTrackingControls();
    this.setupStopAutocomplete('add');
    this.setupStopAutocomplete('edit');
    this.initGeocodeReview();
    this.setupRouteImportModal();
  }

  bindTrackingControls() {
    const toggleBtn = document.getElementById("btn-toggle-route-line");
    if (toggleBtn) {
      toggleBtn.addEventListener("click", () => {
        if (!this.fleetMap) return;
        const isShown = this.fleetMap.toggleRouteLine();
        const textEl = document.getElementById("text-route-line");
        const iconEl = document.getElementById("icon-route-line");
        if (textEl) textEl.textContent = isShown ? "Route Line: ON" : "Route Line: OFF";
        if (iconEl) iconEl.textContent = isShown ? "🛣️" : "📍";
        this.toast(isShown ? "Route line visible on map" : "Route line hidden (live bus movement only)", "info");
      });
    }
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

      routeFilter.addEventListener("change", () => {
        const selectedRouteId = routeFilter.value;
        if (selectedRouteId !== "all") {
          const route = routes.find(r => r.routeId === selectedRouteId);
          const activeBus = buses.find(b => b.routeId === selectedRouteId);
          if (this.fleetMap && route) {
            this.fleetMap.renderRoutePath(route, activeBus);
          }
        } else {
          if (this.fleetMap) this.fleetMap.clearRoutePaths();
        }
        this.renderTracking();
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

    // Update Map with smooth marker interpolation
    if (this.fleetMap) {
      this.fleetMap.updateBuses(filtered, this.selectedBus?.id);
    }
  }

  openBusDrawer(bus) {
    this.selectedBus = bus;
    const drawer = document.getElementById("bus-telemetry-drawer");
    if (!drawer) return;

    const routes = routeService.routes;
    const matchedRoute = routes.find(r => r.routeId === bus.routeId);
    if (this.fleetMap && matchedRoute) {
      this.fleetMap.renderRoutePath(matchedRoute, bus);
    }

    const completedCount = bus.completedStops ? bus.completedStops.length : 0;
    const totalStops = matchedRoute ? matchedRoute.stops.length : 0;
    const headingText = typeof bus.heading === "number" ? `${Math.round(bus.heading)}°` : "N/A";

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
          <div><strong>Heading:</strong> ${headingText}</div>
          <div><strong>Stops Reached:</strong> ${completedCount}${totalStops ? ` / ${totalStops}` : ''}</div>
          <div><strong>Last Update:</strong> ${bus.lastUpdateText}</div>
          <div><strong>Latitude:</strong> ${bus.latitude.toFixed(5)}</div>
          <div><strong>Longitude:</strong> ${bus.longitude.toFixed(5)}</div>
        </div>
        ${bus.completedStops && bus.completedStops.length > 0 ? `
          <div style="margin-bottom:12px;padding:8px 10px;background:#F0FDF4;border:1px solid #BBF7D0;border-radius:8px;font-size:11.5px;color:#166534;">
            <strong>Completed Stops:</strong> ${bus.completedStops.join(" ➔ ")}
          </div>
        ` : ''}
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
      if (this.fleetMap) {
        this.fleetMap.clearRoutePaths();
        this.fleetMap.updateBuses(busService.buses, null);
      }
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

  openAssignRouteModal(uid, name, role = "Driver") {
    const select = document.getElementById("modal-assign-route-select");
    const stopSelect = document.getElementById("modal-assign-stop-select");
    const stopGroup = document.getElementById("modal-assign-stop-group");
    const nameEl = document.getElementById("modal-assign-driver-name");
    const uidInput = document.getElementById("modal-assign-user-uid");
    
    if (nameEl) nameEl.textContent = `${name} (${role})`;
    if (uidInput) uidInput.value = uid;

    const populateStopsForRoute = (routeId) => {
      if (!stopSelect) return;
      const selectedRoute = routeService.routes.find(r => r.routeId === routeId);
      if (selectedRoute && selectedRoute.stops && selectedRoute.stops.length > 0) {
        stopSelect.innerHTML = `<option value="">-- Select Stop --</option>` +
          selectedRoute.stops.map((s, idx) => `<option value="${s}">${idx + 1}. ${s}</option>`).join("");
      } else {
        stopSelect.innerHTML = `<option value="">-- No stops configured --</option>`;
      }
    };

    if (select) {
      select.innerHTML = routeService.routes.map(r => `<option value="${r.routeId}">${r.routeName}</option>`).join("");
      select.onchange = () => populateStopsForRoute(select.value);
      if (routeService.routes.length > 0) {
        populateStopsForRoute(routeService.routes[0].routeId);
      }
    }

    if (stopGroup) {
      stopGroup.style.display = role.toLowerCase() === "student" ? "block" : "none";
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
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center;padding:30px;color:var(--text-muted);">No students registered in /users collection. Use "Bulk CSV Import" to load student roster.</td></tr>`;
      return;
    }

    tbody.innerHTML = students.map(s => `
      <tr>
        <td>
          <div style="font-weight:700;">${s.name}</div>
          <div style="font-size:11.5px;color:var(--text-muted);">${s.email}</div>
        </td>
        <td>
          <div>${s.phone || 'N/A'}</div>
          ${s.rollNumber ? `<div style="font-size:11px;color:var(--text-muted);">Roll: ${s.rollNumber}</div>` : ''}
        </td>
        <td><span class="badge badge-live">${s.assignedRouteName || s.routeName || s.routeId || 'Unassigned'}</span></td>
        <td><span class="badge ${s.selectedStopName && s.selectedStopName !== '—' ? 'badge-live' : 'badge-offline'}">${s.selectedStopName || '—'}</span></td>
        <td><span class="badge badge-offline">Student</span></td>
        <td>
          <button class="btn btn-secondary btn-sm btn-assign-student-route" data-uid="${s.uid}" data-name="${s.name}">
            Assign Route & Stop
          </button>
        </td>
      </tr>
    `).join("");

    tbody.querySelectorAll(".btn-assign-student-route").forEach(btn => {
      btn.addEventListener("click", () => {
        const uid = btn.getAttribute("data-uid");
        const name = btn.getAttribute("data-name");
        this.openAssignRouteModal(uid, name, "Student");
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
          ${r.scheduledTimes && r.scheduledTimes.length > 0 ? `<div style="font-size:11px;color:#0D47A1;margin-top:2px;">🕐 Scheduled: ${r.scheduledTimes.join(" &bull; ")}</div>` : ''}
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

  openAddRouteModal() {
    this.addRouteStops = [];
    document.getElementById("form-add-route")?.reset();
    const stopInput = document.getElementById("add-route-stop-input");
    if (stopInput) stopInput.value = "";
    this.renderStopSequenceList('add');
    this.openModal("modal-add-route");
  }

  openEditRouteModal(route) {
    this.editingRoute = JSON.parse(JSON.stringify(route));
    document.getElementById("form-route-id").value = route.routeId;
    document.getElementById("form-route-name").value = route.routeName;
    document.getElementById("form-route-morning").value = route.schedule?.morning || "7:15 AM";
    document.getElementById("form-route-evening").value = route.schedule?.evening || "5:15 PM";
    
    // Populate this.editRouteStops with exact stop coordinates and scheduled times
    this.editRouteStops = (route.stops || []).map((stopName, idx) => {
      const coord = (route.stopCoordinates && route.stopCoordinates[idx])
        ? route.stopCoordinates[idx]
        : { lat: 13.0850 - (idx * 0.015), lng: 80.2100 + (idx * 0.008) };
      const time = (route.scheduledTimes && route.scheduledTimes[idx]) ? route.scheduledTimes[idx] : "";
      return {
        name: stopName,
        lat: coord.lat,
        lng: coord.lng,
        scheduledTime: time
      };
    });

    const stopInput = document.getElementById("form-route-stop-input");
    if (stopInput) stopInput.value = "";

    this.renderStopSequenceList('edit');
    this.openModal("modal-edit-route");
  }

  /**
   * Searches Chennai presets + live OpenStreetMap Photon API for place autocomplete
   */
  async searchLocations(query) {
    if (!query || query.trim().length < 2) return [];
    const q = query.trim().toLowerCase();
    
    // 1. Instant local matches in curated Chennai transit database
    const localMatches = CHENNAI_PRESET_LOCATIONS.filter(loc => 
      loc.name.toLowerCase().includes(q) || loc.desc.toLowerCase().includes(q)
    ).map(loc => ({ ...loc }));

    // 2. Query live Photon (Komoot / OpenStreetMap) geocoding service centered on Chennai
    try {
      const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&lat=13.0827&lon=80.2707&limit=5`;
      const resp = await fetch(url);
      if (resp.ok) {
        const data = await resp.json();
        if (data.features && Array.isArray(data.features)) {
          for (const f of data.features) {
            const props = f.properties || {};
            const coords = f.geometry?.coordinates || [80.27, 13.08];
            const name = props.name || props.street || query;
            const descParts = [props.street, props.city || props.county, props.state].filter(Boolean);
            const desc = descParts.join(", ") || "Chennai, Tamil Nadu";
            
            // Avoid duplicates
            if (!localMatches.some(m => m.name.toLowerCase() === name.toLowerCase())) {
              localMatches.push({
                name: name,
                desc: desc,
                lat: coords[1],
                lng: coords[0]
              });
            }
          }
        }
      }
    } catch (err) {
      console.warn("Photon autocomplete warning:", err);
    }

    return localMatches.slice(0, 6);
  }

  /**
   * Binds autocomplete input, dropdown and click listeners for Add/Edit route modals
   */
  setupStopAutocomplete(type) {
    const inputId = type === 'add' ? 'add-route-stop-input' : 'form-route-stop-input';
    const dropdownId = type === 'add' ? 'add-route-autocomplete-list' : 'form-route-autocomplete-list';
    const manualBtnId = type === 'add' ? 'btn-add-stop-manual' : 'btn-edit-stop-manual';

    const input = document.getElementById(inputId);
    const dropdown = document.getElementById(dropdownId);
    const manualBtn = document.getElementById(manualBtnId);

    if (!input || !dropdown) return;

    let debounceTimer = null;

    input.addEventListener("input", (e) => {
      clearTimeout(debounceTimer);
      const val = e.target.value.trim();
      if (val.length < 2) {
        dropdown.style.display = "none";
        dropdown.innerHTML = "";
        return;
      }

      debounceTimer = setTimeout(async () => {
        const results = await this.searchLocations(val);
        if (results.length === 0) {
          dropdown.innerHTML = `<div style="padding:10px 14px;color:var(--text-muted);font-size:12px;">No matching locations found. Click "+ Add" to add custom name.</div>`;
          dropdown.style.display = "block";
          return;
        }

        dropdown.innerHTML = results.map((item, idx) => `
          <div class="autocomplete-item" data-idx="${idx}">
            <span class="autocomplete-item-icon">📍</span>
            <div class="autocomplete-item-info">
              <div class="autocomplete-item-name">${item.name}</div>
              <div class="autocomplete-item-desc">${item.desc} (${item.lat.toFixed(4)}, ${item.lng.toFixed(4)})</div>
            </div>
          </div>
        `).join("");
        dropdown.style.display = "block";

        dropdown.querySelectorAll(".autocomplete-item").forEach(itemEl => {
          itemEl.addEventListener("click", () => {
            const idx = parseInt(itemEl.getAttribute("data-idx"), 10);
            const selected = results[idx];
            if (!selected) return;

            const targetArray = type === 'add' ? this.addRouteStops : this.editRouteStops;
            targetArray.push({
              name: selected.name,
              lat: selected.lat,
              lng: selected.lng,
              scheduledTime: ""
            });

            input.value = "";
            dropdown.style.display = "none";
            dropdown.innerHTML = "";
            this.renderStopSequenceList(type);
          });
        });
      }, 250);
    });

    // Hide dropdown on outside click
    document.addEventListener("click", (e) => {
      if (!input.contains(e.target) && !dropdown.contains(e.target)) {
        dropdown.style.display = "none";
      }
    });

    // Manual Add button handler
    if (manualBtn) {
      manualBtn.addEventListener("click", () => {
        const val = input.value.trim();
        if (!val) return;

        const targetArray = type === 'add' ? this.addRouteStops : this.editRouteStops;
        // Default coordinate around Chennai if custom
        const lat = 13.0850 - (targetArray.length * 0.015);
        const lng = 80.2100 + (targetArray.length * 0.008);

        targetArray.push({
          name: val,
          lat: lat,
          lng: lng,
          scheduledTime: ""
        });

        input.value = "";
        dropdown.style.display = "none";
        this.renderStopSequenceList(type);
      });
    }
  }

  /**
   * Renders the interactive sequence of added stops with time and remove options
   */
  renderStopSequenceList(type) {
    const listId = type === 'add' ? 'add-route-stops-list' : 'form-route-stops-list';
    const hiddenTextareaId = type === 'add' ? 'add-route-stops' : 'form-route-stops';
    const hiddenTimesId = type === 'add' ? 'add-route-scheduled-times' : 'form-route-scheduled-times';

    const container = document.getElementById(listId);
    const targetArray = type === 'add' ? this.addRouteStops : this.editRouteStops;

    if (container) {
      if (targetArray.length === 0) {
        container.innerHTML = `<div style="padding:14px;background:#F8FAFC;border:1px dashed #CBD5E1;border-radius:8px;text-align:center;font-size:12px;color:var(--text-muted);">No stops added yet. Type a location above (e.g. Nathamuni) to select.</div>`;
      } else {
        container.innerHTML = targetArray.map((stop, i) => `
          <div class="stop-sequence-item" data-index="${i}">
            <div class="stop-seq-number">${i + 1}</div>
            <div class="stop-seq-details">
              <div class="stop-seq-name">${stop.name}</div>
              <div class="stop-seq-coord">📍 ${stop.lat.toFixed(4)}, ${stop.lng.toFixed(4)}</div>
            </div>
            <input type="text" class="stop-seq-time" placeholder="e.g. 7:30 AM" value="${stop.scheduledTime || ''}" title="Scheduled Arrival Time" />
            <button type="button" class="stop-seq-remove" title="Remove Stop">&times;</button>
          </div>
        `).join("");

        // Bind remove buttons and time change listeners
        container.querySelectorAll(".stop-sequence-item").forEach(itemEl => {
          const idx = parseInt(itemEl.getAttribute("data-index"), 10);
          const timeInput = itemEl.querySelector(".stop-seq-time");
          const removeBtn = itemEl.querySelector(".stop-seq-remove");

          if (timeInput) {
            timeInput.addEventListener("input", (e) => {
              if (targetArray[idx]) targetArray[idx].scheduledTime = e.target.value.trim();
              this.syncHiddenFields(type);
            });
          }

          if (removeBtn) {
            removeBtn.addEventListener("click", () => {
              targetArray.splice(idx, 1);
              this.renderStopSequenceList(type);
            });
          }
        });
      }
    }

    this.syncHiddenFields(type);
  }

  syncHiddenFields(type) {
    const hiddenTextareaId = type === 'add' ? 'add-route-stops' : 'form-route-stops';
    const hiddenTimesId = type === 'add' ? 'add-route-scheduled-times' : 'form-route-scheduled-times';
    const targetArray = type === 'add' ? this.addRouteStops : this.editRouteStops;

    const textarea = document.getElementById(hiddenTextareaId);
    const timesInput = document.getElementById(hiddenTimesId);

    if (textarea) textarea.value = targetArray.map(s => s.name).join(", ");
    if (timesInput) timesInput.value = targetArray.map(s => s.scheduledTime || "").join(", ");
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

    // Close when clicking outside modal box
    document.querySelectorAll(".modal-backdrop").forEach(backdrop => {
      backdrop.addEventListener("click", (e) => {
        if (e.target === backdrop) {
          this.closeAllModals();
        }
      });
    });

    // Close on Escape key
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        this.closeAllModals();
      }
    });

    document.querySelectorAll("[data-open-modal]").forEach(btn => {
      btn.addEventListener("click", () => {
        const modalId = btn.getAttribute("data-open-modal");
        if (modalId === "modal-add-route") {
          this.openAddRouteModal();
        } else {
          this.openModal(modalId);
        }
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
    // Seed Routes Button (opens safe selection modal)
    document.getElementById("btn-seed-routes")?.addEventListener("click", () => {
      this.openRouteImportModal("default");
    });

    // Direct Morning Routes Import Button (opens safe selection modal)
    document.getElementById("btn-open-morning-import")?.addEventListener("click", () => {
      this.openRouteImportModal("morning");
    });

    // Form: Create New Route
    document.getElementById("form-add-route")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const id = document.getElementById("add-route-id").value.trim();
      const name = document.getElementById("add-route-name").value.trim();
      const morning = document.getElementById("add-route-morning").value.trim();
      const evening = document.getElementById("add-route-evening").value.trim();

      let stops = [];
      let stopCoordinates = [];
      let scheduledTimes = [];

      if (this.addRouteStops && this.addRouteStops.length > 0) {
        stops = this.addRouteStops.map(s => s.name);
        stopCoordinates = this.addRouteStops.map(s => ({ lat: s.lat, lng: s.lng }));
        scheduledTimes = this.addRouteStops.map(s => s.scheduledTime || "");
      } else {
        const stopsStr = document.getElementById("add-route-stops").value.trim();
        const scheduledTimesStr = document.getElementById("add-route-scheduled-times")?.value.trim() || "";
        stops = stopsStr.split(",").map(s => s.trim()).filter(Boolean);
        scheduledTimes = scheduledTimesStr ? scheduledTimesStr.split(",").map(s => s.trim()).filter(Boolean) : [];
        stopCoordinates = stops.map((_, i) => ({
          lat: 13.0850 - (i * 0.015),
          lng: 80.2100 + (i * 0.008)
        }));
      }

      if (stops.length === 0) {
        this.toast("Please add at least 1 stop to the route.", "warning");
        return;
      }

      this.toast(`Saving route "${name}" & computing road paths...`, "info");

      await routeService.saveRoute({
        routeId: id,
        routeName: name,
        stops: stops,
        scheduledTimes: scheduledTimes,
        stopCoordinates: stopCoordinates,
        schedule: { morning, evening },
        isActive: true
      });

      await auditService.logAction("ROUTE_CREATED", "ROUTE", id, { name, stopsCount: stops.length }, authService.userProfile);
      this.closeAllModals();
      this.toast(`New route "${name}" created with accurate GPS stops & road path!`);
    });

    // Form: Edit Route
    document.getElementById("form-edit-route")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const id = document.getElementById("form-route-id").value;
      const name = document.getElementById("form-route-name").value;
      const morning = document.getElementById("form-route-morning").value;
      const evening = document.getElementById("form-route-evening").value;

      let stops = [];
      let stopCoordinates = [];
      let scheduledTimes = [];

      if (this.editRouteStops && this.editRouteStops.length > 0) {
        stops = this.editRouteStops.map(s => s.name);
        stopCoordinates = this.editRouteStops.map(s => ({ lat: s.lat, lng: s.lng }));
        scheduledTimes = this.editRouteStops.map(s => s.scheduledTime || "");
      } else {
        const stopsStr = document.getElementById("form-route-stops").value;
        const scheduledTimesStr = document.getElementById("form-route-scheduled-times")?.value.trim() || "";
        stops = stopsStr.split(",").map(s => s.trim()).filter(Boolean);
        scheduledTimes = scheduledTimesStr ? scheduledTimesStr.split(",").map(s => s.trim()).filter(Boolean) : [];
        stopCoordinates = stops.map((_, i) => ({
          lat: 13.0850 - (i * 0.015),
          lng: 80.2100 + (i * 0.008)
        }));
      }

      if (stops.length === 0) {
        this.toast("Please add at least 1 stop to the route.", "warning");
        return;
      }

      this.toast(`Updating route "${name}" & regenerating street polyline...`, "info");

      await routeService.saveRoute({
        routeId: id,
        routeName: name,
        stops: stops,
        scheduledTimes: scheduledTimes,
        stopCoordinates: stopCoordinates,
        schedule: { morning, evening },
        isActive: true
      });

      await auditService.logAction("ROUTE_SAVED", "ROUTE", id, { name, stopsCount: stops.length }, authService.userProfile);
      this.closeAllModals();
      this.toast(`Route "${name}" saved with updated stop GPS coordinates!`);
    });

    // Form: Assign Route to Driver/Student
    document.getElementById("form-assign-route")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const uid = document.getElementById("modal-assign-user-uid").value;
      const routeId = document.getElementById("modal-assign-route-select").value;
      const stopName = document.getElementById("modal-assign-stop-select")?.value || "";
      const route = routeService.routes.find(r => r.routeId === routeId);

      await userService.assignRoute(uid, routeId, route?.routeName, stopName);
      await auditService.logAction("USER_ROUTE_ASSIGNED", "USER", uid, { routeId, routeName: route?.routeName, stopName }, authService.userProfile);
      this.closeAllModals();
      this.toast(`Route assignment updated successfully.`);
    });

    // CSV File Selection & Parsing Handler
    const csvFileInput = document.getElementById("csv-file-input");
    const previewContainer = document.getElementById("csv-preview-container");
    const previewTbody = document.getElementById("csv-preview-tbody");
    const recordCountEl = document.getElementById("csv-record-count");
    const submitCsvBtn = document.getElementById("btn-submit-csv");

    csvFileInput?.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (event) => {
        const text = event.target.result;
        const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
        if (lines.length < 2) {
          this.toast("CSV file must contain a header row and data rows.", "error");
          return;
        }

        // Header: Name, Email, Phone, RollNumber, RouteId, StopName
        const parsed = [];
        for (let i = 1; i < lines.length; i++) {
          const parts = lines[i].split(",").map(p => p.trim().replace(/^["']|["']$/g, ''));
          if (parts.length >= 2) {
            parsed.push({
              name: parts[0] || "Student",
              email: parts[1] || "",
              phone: parts[2] || "",
              rollNumber: parts[3] || "",
              routeId: parts[4] || "",
              stopName: parts[5] || ""
            });
          }
        }

        this.parsedCsvData = parsed;
        if (recordCountEl) recordCountEl.textContent = parsed.length;
        if (previewTbody) {
          previewTbody.innerHTML = parsed.slice(0, 10).map(row => `
            <tr>
              <td style="padding:4px 8px;">${row.name}</td>
              <td style="padding:4px 8px;">${row.email}</td>
              <td style="padding:4px 8px;">${row.routeId || '—'}</td>
              <td style="padding:4px 8px;">${row.stopName || '—'}</td>
            </tr>
          `).join("");
        }

        if (previewContainer) previewContainer.style.display = "block";
        if (submitCsvBtn) submitCsvBtn.disabled = parsed.length === 0;
      };
      reader.readAsText(file);
    });

    // Form: Submit Bulk CSV Import
    document.getElementById("form-csv-import")?.addEventListener("submit", async (e) => {
      e.preventDefault();
      if (!this.parsedCsvData || this.parsedCsvData.length === 0) {
        this.toast("Please select a valid CSV file first.", "error");
        return;
      }

      const count = await userService.batchImportStudents(this.parsedCsvData);
      await auditService.logAction("STUDENTS_BULK_IMPORTED", "STUDENT", "BATCH", { count }, authService.userProfile);
      this.closeAllModals();
      this.toast(`Successfully imported ${count} student records to Firestore!`);
      this.parsedCsvData = [];
      if (csvFileInput) csvFileInput.value = "";
      if (previewContainer) previewContainer.style.display = "none";
      if (submitCsvBtn) submitCsvBtn.disabled = true;
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

  // ============================================================
  // PHASE 2: GEOCODE REVIEW & PIN ADJUSTER CONTROLLER
  // ============================================================
  initGeocodeReview() {
    this.morningRoutes = JSON.parse(JSON.stringify(MORNING_ROUTES_DATA));
    this.selectedGeocodeRouteIdx = null;
    this.selectedGeocodeStopIdx = null;
    this.geocodeMap = null;
    this.geocodeMarker = null;

    const openBtn = document.getElementById("btn-open-geocode-review");
    if (openBtn) {
      openBtn.addEventListener("click", () => {
        this.openModal("modal-geocode-review");
        this.renderGeocodeReview();
        setTimeout(() => {
          if (!this.geocodeMap) {
            this.geocodeMap = L.map("rev-map-el").setView([13.0827, 80.2707], 11);
            L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
              attribution: "&copy; OpenStreetMap contributors"
            }).addTo(this.geocodeMap);
          } else {
            this.geocodeMap.invalidateSize();
          }
        }, 300);
      });
    }

    const filterSelect = document.getElementById("rev-filter-status");
    if (filterSelect) {
      filterSelect.addEventListener("change", () => {
        this.renderGeocodeReviewStops(filterSelect.value);
      });
    }

    const downloadCsvBtn = document.getElementById("btn-download-geocode-csv");
    if (downloadCsvBtn) {
      downloadCsvBtn.addEventListener("click", () => {
        this.downloadGeocodeCsv();
      });
    }

    const saveManualBtn = document.getElementById("btn-save-manual-coord");
    if (saveManualBtn) {
      saveManualBtn.addEventListener("click", () => {
        this.saveManualStopCoordinates();
      });
    }

    const latInput = document.getElementById("rev-input-lat");
    const lngInput = document.getElementById("rev-input-lng");
    [latInput, lngInput].forEach(inp => {
      inp?.addEventListener("change", () => {
        const lat = parseFloat(latInput.value);
        const lng = parseFloat(lngInput.value);
        if (!isNaN(lat) && !isNaN(lng) && this.geocodeMarker && this.geocodeMap) {
          this.geocodeMarker.setLatLng([lat, lng]);
          this.geocodeMap.panTo([lat, lng]);
        }
      });
    });

    const importAllBtn = document.getElementById("btn-import-all-morning-routes");
    if (importAllBtn) {
      importAllBtn.addEventListener("click", async () => {
        await this.importApprovedMorningRoutes();
      });
    }
  }

  renderGeocodeReview() {
    let total = 0;
    let ok = 0;
    let review = 0;
    let failed = 0;

    this.morningRoutes.forEach(r => {
      r.stopCoordinates.forEach(s => {
        total++;
        if (s.status === "ok" || s.status === "ok_manual") ok++;
        else if (s.status === "needs_review") review++;
        else failed++;
      });
    });

    const setT = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setT("rev-stat-total", total);
    setT("rev-stat-ok", ok);
    setT("rev-stat-review", review);
    setT("rev-stat-failed", failed);

    const filterSelect = document.getElementById("rev-filter-status");
    this.renderGeocodeReviewStops(filterSelect ? filterSelect.value : "needs_review");
  }

  renderGeocodeReviewStops(filter = "all") {
    const listEl = document.getElementById("rev-stops-list");
    if (!listEl) return;

    const items = [];
    this.morningRoutes.forEach((route, rIdx) => {
      route.stopCoordinates.forEach((stop, sIdx) => {
        if (filter === "needs_review" && stop.status !== "needs_review") return;
        if (filter === "ok" && stop.status !== "ok" && stop.status !== "ok_manual") return;

        items.push({
          routeIdx: rIdx,
          stopIdx: sIdx,
          routeNumber: route.routeNumber,
          routeName: route.routeName,
          stopName: stop.name,
          scheduledTime: stop.scheduledTime,
          status: stop.status,
          lat: stop.lat,
          lng: stop.lng,
          address: stop.address || ""
        });
      });
    });

    if (items.length === 0) {
      listEl.innerHTML = `<div style="padding:30px;text-align:center;color:var(--text-muted);font-size:12px;">No stops match filter "${filter}".</div>`;
      return;
    }

    listEl.innerHTML = items.map((it) => {
      const isSelected = this.selectedGeocodeRouteIdx === it.routeIdx && this.selectedGeocodeStopIdx === it.stopIdx;
      const statusColor = it.status === "ok" ? "#059669" : (it.status === "ok_manual" ? "#0284C7" : (it.status === "needs_review" ? "#D97706" : "#DC2626"));
      const statusBadge = it.status === "ok" ? "OK" : (it.status === "ok_manual" ? "OK (Manual)" : (it.status === "needs_review" ? "Needs Review" : "Failed"));

      return `
        <div class="geocode-stop-item" data-ridx="${it.routeIdx}" data-sidx="${it.stopIdx}" style="padding:8px 12px;border-bottom:1px solid var(--border);cursor:pointer;display:flex;align-items:center;justify-content:space-between;background:${isSelected ? '#E0F2FE' : 'transparent'};font-size:12px;">
          <div>
            <div style="font-weight:700;">R${it.routeNumber}: ${it.stopName}</div>
            <div style="font-size:11px;color:var(--text-muted);margin-top:2px;">Route ${it.routeName} &bull; 🕐 ${it.scheduledTime || '—'}</div>
          </div>
          <span style="font-size:10px;font-weight:700;padding:2px 6px;border-radius:4px;color:white;background:${statusColor};white-space:nowrap;">
            ${statusBadge}
          </span>
        </div>
      `;
    }).join("");

    listEl.querySelectorAll(".geocode-stop-item").forEach(el => {
      el.addEventListener("click", () => {
        const rIdx = parseInt(el.getAttribute("data-ridx"), 10);
        const sIdx = parseInt(el.getAttribute("data-sidx"), 10);
        this.inspectGeocodeStop(rIdx, sIdx);
      });
    });

    // Auto-select first item if none selected
    if (this.selectedGeocodeRouteIdx === null && items.length > 0) {
      this.inspectGeocodeStop(items[0].routeIdx, items[0].stopIdx);
    }
  }

  inspectGeocodeStop(rIdx, sIdx) {
    this.selectedGeocodeRouteIdx = rIdx;
    this.selectedGeocodeStopIdx = sIdx;

    const route = this.morningRoutes[rIdx];
    const stop = route.stopCoordinates[sIdx];

    const titleEl = document.getElementById("rev-selected-stop-title");
    const metaEl = document.getElementById("rev-selected-stop-meta");
    const latInput = document.getElementById("rev-input-lat");
    const lngInput = document.getElementById("rev-input-lng");
    const gmapsLink = document.getElementById("rev-gmaps-link");

    if (titleEl) titleEl.textContent = `Route ${route.routeNumber} (${route.routeName}) — Stop ${sIdx + 1}: ${stop.name}`;
    if (metaEl) metaEl.textContent = `Status: ${stop.status.toUpperCase()} &bull; Scheduled: ${stop.scheduledTime} &bull; Source: ${stop.source || 'nominatim'}`;
    if (latInput) latInput.value = stop.lat !== null && stop.lat !== undefined ? stop.lat : "";
    if (lngInput) lngInput.value = stop.lng !== null && stop.lng !== undefined ? stop.lng : "";

    if (gmapsLink) {
      if (stop.lat && stop.lng) {
        gmapsLink.href = `https://www.google.com/maps?q=${stop.lat},${stop.lng}`;
        gmapsLink.style.display = "inline-block";
      } else {
        gmapsLink.style.display = "none";
      }
    }

    // Update map marker
    const lat = stop.lat || 13.0827;
    const lng = stop.lng || 80.2707;

    if (this.geocodeMap) {
      this.geocodeMap.setView([lat, lng], 14);
      if (this.geocodeMarker) {
        this.geocodeMarker.setLatLng([lat, lng]);
      } else {
        this.geocodeMarker = L.marker([lat, lng], { draggable: true }).addTo(this.geocodeMap);
        this.geocodeMarker.on("dragend", (e) => {
          const pos = e.target.getLatLng();
          if (latInput) latInput.value = pos.lat.toFixed(6);
          if (lngInput) lngInput.value = pos.lng.toFixed(6);
          if (gmapsLink) {
            gmapsLink.href = `https://www.google.com/maps?q=${pos.lat.toFixed(6)},${pos.lng.toFixed(6)}`;
          }
        });
      }
    }

    // Highlight in list
    document.querySelectorAll(".geocode-stop-item").forEach(el => {
      const isThis = parseInt(el.getAttribute("data-ridx"), 10) === rIdx && parseInt(el.getAttribute("data-sidx"), 10) === sIdx;
      el.style.background = isThis ? "#E0F2FE" : "transparent";
    });
  }

  saveManualStopCoordinates() {
    if (this.selectedGeocodeRouteIdx === null || this.selectedGeocodeStopIdx === null) {
      this.toast("Please select a stop to adjust.", "warning");
      return;
    }

    const latInput = document.getElementById("rev-input-lat");
    const lngInput = document.getElementById("rev-input-lng");
    const lat = parseFloat(latInput?.value);
    const lng = parseFloat(lngInput?.value);

    if (isNaN(lat) || isNaN(lng)) {
      this.toast("Please provide valid latitude and longitude numbers.", "error");
      return;
    }

    const route = this.morningRoutes[this.selectedGeocodeRouteIdx];
    const stop = route.stopCoordinates[this.selectedGeocodeStopIdx];

    stop.lat = lat;
    stop.lng = lng;
    stop.status = "ok_manual";
    stop.source = "manual_admin_adjuster";

    this.toast(`Updated Stop "${stop.name}" coordinates to (${lat.toFixed(5)}, ${lng.toFixed(5)}) as OK (Manual)!`);
    this.renderGeocodeReview();
  }

  downloadGeocodeCsv() {
    let csv = "RouteNumber,RouteDocId,StopIndex,StopName,ScheduledTime,Status,Confidence,Source,Lat,Lng,Address,GoogleMapsUrl\n";
    this.morningRoutes.forEach(r => {
      r.stopCoordinates.forEach((s, idx) => {
        const mapsUrl = s.lat && s.lng ? `https://www.google.com/maps?q=${s.lat},${s.lng}` : "N/A";
        const safeName = `"${s.name.replace(/"/g, '""')}"`;
        const safeAddr = `"${(s.address || '').replace(/"/g, '""')}"`;
        csv += `${r.routeNumber},${r.routeId},${idx + 1},${safeName},${s.scheduledTime || ''},${s.status},${s.confidence || 1.0},${s.source || 'cache'},${s.lat || ''},${s.lng || ''},${safeAddr},${mapsUrl}\n`;
      });
    });

    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "geocode_review.csv";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    this.toast("Downloaded geocode_review.csv");
  }

  async importApprovedMorningRoutes() {
    this.closeAllModals();
    this.openRouteImportModal("morning");
  }

  // ============================================================
  // ROUTE SELECTION & IMPORT MODAL CONTROLLER
  // ============================================================
  setupRouteImportModal() {
    this.routeImportType = "default"; // 'default' or 'morning'
    this.routeImportCandidates = [];
    this.routeImportSelectedIds = new Set();
    this.routeImportExistingMap = {};
    this.routeImportFiltered = [];

    const searchInput = document.getElementById("route-import-search");
    searchInput?.addEventListener("input", () => {
      this.filterRouteImportList(searchInput.value);
    });

    const selectAllCheckbox = document.getElementById("route-import-select-all");
    selectAllCheckbox?.addEventListener("change", () => {
      const isChecked = selectAllCheckbox.checked;
      this.routeImportFiltered.forEach(r => {
        if (isChecked) {
          this.routeImportSelectedIds.add(r.routeId);
        } else {
          this.routeImportSelectedIds.delete(r.routeId);
        }
      });
      this.syncRouteImportCheckboxes();
      this.updateRouteImportState();
    });

    document.getElementById("btn-import-select-new")?.addEventListener("click", () => {
      this.routeImportSelectedIds.clear();
      this.routeImportCandidates.forEach(r => {
        if (r._importStatus === "NEW") {
          this.routeImportSelectedIds.add(r.routeId);
        }
      });
      this.syncRouteImportCheckboxes();
      this.updateRouteImportState();
    });

    document.getElementById("btn-import-clear")?.addEventListener("click", () => {
      this.routeImportSelectedIds.clear();
      this.syncRouteImportCheckboxes();
      this.updateRouteImportState();
    });

    document.getElementById("route-import-confirm-overwrite")?.addEventListener("change", () => {
      this.updateRouteImportState();
    });

    document.getElementById("btn-route-import-submit")?.addEventListener("click", async () => {
      await this.executeRouteImport();
    });

    // Dataset Switcher Tabs inside the modal
    document.getElementById("btn-dataset-switch-80")?.addEventListener("click", () => {
      this.switchRouteImportDataset("morning");
    });
    document.getElementById("btn-dataset-switch-10")?.addEventListener("click", () => {
      this.switchRouteImportDataset("legacy10");
    });
  }

  switchRouteImportDataset(type) {
    this.routeImportType = type;
    const btn80 = document.getElementById("btn-dataset-switch-80");
    const btn10 = document.getElementById("btn-dataset-switch-10");
    if (type === "legacy10") {
      if (btn80) {
        btn80.style.background = "transparent";
        btn80.style.color = "var(--text-muted)";
        btn80.style.boxShadow = "none";
      }
      if (btn10) {
        btn10.style.background = "white";
        btn10.style.color = "var(--text-primary)";
        btn10.style.boxShadow = "0 1px 2px rgba(0,0,0,0.05)";
      }
    } else {
      if (btn80) {
        btn80.style.background = "white";
        btn80.style.color = "var(--text-primary)";
        btn80.style.boxShadow = "0 1px 2px rgba(0,0,0,0.05)";
      }
      if (btn10) {
        btn10.style.background = "transparent";
        btn10.style.color = "var(--text-muted)";
        btn10.style.boxShadow = "none";
      }
    }
    this.populateRouteImportCandidates();
  }

  async openRouteImportModal(type = "default") {
    // Default to the 80 campus morning routes dataset!
    this.routeImportType = (type === "legacy10") ? "legacy10" : "morning";
    this.routeImportSelectedIds.clear();

    const searchInput = document.getElementById("route-import-search");
    const conflictBanner = document.getElementById("route-import-conflict-banner");
    const confirmOverwriteCheck = document.getElementById("route-import-confirm-overwrite");
    const progressBox = document.getElementById("route-import-progress-box");
    const summaryBox = document.getElementById("route-import-result-summary");
    const submitBtn = document.getElementById("btn-route-import-submit");

    if (searchInput) searchInput.value = "";
    if (conflictBanner) conflictBanner.style.display = "none";
    if (confirmOverwriteCheck) confirmOverwriteCheck.checked = false;
    if (progressBox) progressBox.style.display = "none";
    if (summaryBox) {
      summaryBox.style.display = "none";
      summaryBox.innerHTML = "";
    }
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.textContent = "Import Selected (0)";
    }

    const tbody = document.getElementById("route-import-tbody");
    if (tbody) {
      tbody.innerHTML = `<tr><td colspan="5" style="padding:30px;text-align:center;color:var(--text-muted);">Fetching existing routes from Cloud Firestore...</td></tr>`;
    }

    // Sync dataset switch buttons UI
    const btn80 = document.getElementById("btn-dataset-switch-80");
    const btn10 = document.getElementById("btn-dataset-switch-10");
    if (this.routeImportType === "legacy10") {
      if (btn80) {
        btn80.style.background = "transparent";
        btn80.style.color = "var(--text-muted)";
        btn80.style.boxShadow = "none";
      }
      if (btn10) {
        btn10.style.background = "white";
        btn10.style.color = "var(--text-primary)";
        btn10.style.boxShadow = "0 1px 2px rgba(0,0,0,0.05)";
      }
    } else {
      if (btn80) {
        btn80.style.background = "white";
        btn80.style.color = "var(--text-primary)";
        btn80.style.boxShadow = "0 1px 2px rgba(0,0,0,0.05)";
      }
      if (btn10) {
        btn10.style.background = "transparent";
        btn10.style.color = "var(--text-muted)";
        btn10.style.boxShadow = "none";
      }
    }

    this.openModal("modal-route-import");

    // Step 1: Single read to get existing Firestore routes map
    try {
      this.routeImportExistingMap = await routeService.getExistingRoutesMap();
    } catch (err) {
      console.warn("[RouteImport] Error fetching existing map, using cached routes:", err);
      this.routeImportExistingMap = {};
      routeService.routes.forEach(r => {
        this.routeImportExistingMap[r.routeId || r.id] = r;
      });
    }

    // Step 2: Populate candidate routes
    this.populateRouteImportCandidates();
  }

  populateRouteImportCandidates() {
    this.routeImportSelectedIds.clear();

    const titleEl = document.getElementById("route-import-modal-title");
    const subEl = document.getElementById("route-import-modal-sub");

    let rawDataset = [];
    if (this.routeImportType === "legacy10") {
      rawDataset = DEFAULT_CHENNAI_ROUTES;
      if (titleEl) titleEl.textContent = "⚡ Seed Standard Transit Routes (10 Routes)";
      if (subEl) subEl.textContent = "Select standard Chennai transit routes to write to Firestore.";
    } else {
      rawDataset = (this.morningRoutes && this.morningRoutes.length > 0) ? this.morningRoutes : MORNING_ROUTES_DATA;
      if (titleEl) titleEl.textContent = `⚡ Seed Default Routes (${rawDataset.length} Campus Routes)`;
      if (subEl) subEl.textContent = `Select from all ${rawDataset.length} Chennai campus routes to write to Firestore. Existing routes and driver assignments are preserved.`;
    }

    this.routeImportCandidates = rawDataset.map(r => {
      const routeId = r.routeId || r.id;
      const existing = this.routeImportExistingMap ? this.routeImportExistingMap[routeId] : null;
      let status = "NEW"; // "NEW", "EXISTS", "CONFLICT"
      let conflictNote = "";

      if (existing) {
        const normExisting = (existing.routeName || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const normCand = (r.routeName || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const isMatch = normExisting === normCand || normExisting.includes(normCand) || normCand.includes(normExisting);

        if (isMatch) {
          status = "EXISTS";
        } else {
          status = "CONFLICT";
          conflictNote = `Conflicts with existing Firestore route "${existing.routeName || existing.id}"`;
        }
      }

      // Checkbox defaults: checked if NEW, unchecked if EXISTS or CONFLICT
      if (status === "NEW") {
        this.routeImportSelectedIds.add(routeId);
      }

      return {
        ...r,
        routeId,
        _importStatus: status,
        _conflictNote: conflictNote,
        _existingDoc: existing
      };
    });

    const searchInput = document.getElementById("route-import-search");
    if (searchInput && searchInput.value) {
      this.filterRouteImportList(searchInput.value);
    } else {
      this.routeImportFiltered = [...this.routeImportCandidates];
      this.renderRouteImportList();
      this.updateRouteImportState();
    }
  }

  filterRouteImportList(query) {
    const q = (query || "").trim().toLowerCase();
    if (!q) {
      this.routeImportFiltered = [...this.routeImportCandidates];
    } else {
      this.routeImportFiltered = this.routeImportCandidates.filter(r => {
        const idMatch = (r.routeId || "").toLowerCase().includes(q);
        const numMatch = (r.routeNumber || "").toString().toLowerCase().includes(q);
        const nameMatch = (r.routeName || "").toLowerCase().includes(q);
        const stopsMatch = Array.isArray(r.stops) && r.stops.some(s => s.toLowerCase().includes(q));
        return idMatch || numMatch || nameMatch || stopsMatch;
      });
    }
    this.renderRouteImportList();
    this.updateRouteImportState();
  }

  renderRouteImportList() {
    const tbody = document.getElementById("route-import-tbody");
    if (!tbody) return;

    if (this.routeImportFiltered.length === 0) {
      tbody.innerHTML = `<tr><td colspan="5" style="padding:30px;text-align:center;color:var(--text-muted);">No matching routes found.</td></tr>`;
      return;
    }

    tbody.innerHTML = this.routeImportFiltered.map(r => {
      const isChecked = this.routeImportSelectedIds.has(r.routeId);
      const stopCount = Array.isArray(r.stops) ? r.stops.length : 0;
      const startStop = stopCount > 0 ? r.stops[0] : "—";
      const endStop = stopCount > 1 ? r.stops[stopCount - 1] : "";

      // Schedule formatting
      let schedText = "—";
      if (r.schedule) {
        if (typeof r.schedule === "object") {
          schedText = `${r.schedule.morning || ""}${r.schedule.evening ? " / " + r.schedule.evening : ""}`;
        } else {
          schedText = String(r.schedule);
        }
      } else if (Array.isArray(r.scheduledTimes) && r.scheduledTimes.length > 0) {
        schedText = `${r.scheduledTimes[0]} - ${r.scheduledTimes[r.scheduledTimes.length - 1]}`;
      }

      // Badge formatting
      let badgeHtml = "";
      let rowClass = "route-import-row";
      if (isChecked) rowClass += " selected";

      if (r._importStatus === "NEW") {
        badgeHtml = `<span class="badge badge-live">New</span>`;
      } else if (r._importStatus === "EXISTS") {
        badgeHtml = `<span class="badge badge-stale" title="Route exists in Firestore">Already exists</span>`;
      } else if (r._importStatus === "CONFLICT") {
        rowClass += " conflict";
        badgeHtml = `<span class="badge badge-conflict" title="${r._conflictNote}">⚠️ Conflict</span>`;
      }

      return `
        <tr class="${rowClass}" data-route-id="${r.routeId}">
          <td style="padding:10px 12px;text-align:center;">
            <input type="checkbox" class="route-import-checkbox" data-route-id="${r.routeId}" ${isChecked ? 'checked' : ''} style="cursor:pointer;width:15px;height:15px;" />
          </td>
          <td style="padding:10px 12px;">
            <div style="font-weight:700;color:var(--text-primary);font-family:var(--font-heading);">${r.routeName || r.routeId}</div>
            <div style="font-size:11px;color:var(--text-muted);font-family:var(--font-mono);">${r.routeId}${r.routeNumber ? ` • Bus #${r.routeNumber}` : ''}</div>
          </td>
          <td style="padding:10px 12px;">
            <div style="font-weight:600;font-size:12px;">${stopCount} Stops</div>
            <div style="font-size:11px;color:var(--text-muted);max-width:260px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
              ${startStop}${endStop ? ' ➔ ' + endStop : ''}
            </div>
          </td>
          <td style="padding:10px 12px;font-size:12px;color:var(--text-secondary);font-family:var(--font-mono);">
            ${schedText}
          </td>
          <td style="padding:10px 12px;text-align:right;">
            <div>${badgeHtml}</div>
            ${r._conflictNote ? `<div style="font-size:10.5px;color:#DC2626;margin-top:2px;">${r._conflictNote}</div>` : ''}
            ${(r._importStatus === "EXISTS" && isChecked) ? `<div style="font-size:10.5px;color:#D97706;margin-top:2px;">Will update existing doc</div>` : ''}
          </td>
        </tr>
      `;
    }).join("");

    // Bind row click & checkbox listeners
    tbody.querySelectorAll(".route-import-row").forEach(row => {
      row.addEventListener("click", (e) => {
        if (e.target.tagName === "INPUT" && e.target.type === "checkbox") return;
        const routeId = row.getAttribute("data-route-id");
        const chk = row.querySelector(".route-import-checkbox");
        if (chk) {
          chk.checked = !chk.checked;
          if (chk.checked) this.routeImportSelectedIds.add(routeId);
          else this.routeImportSelectedIds.delete(routeId);
          this.updateRouteImportRowClass(row, chk.checked);
          this.updateRouteImportState();
        }
      });
    });

    tbody.querySelectorAll(".route-import-checkbox").forEach(chk => {
      chk.addEventListener("change", () => {
        const routeId = chk.getAttribute("data-route-id");
        if (chk.checked) this.routeImportSelectedIds.add(routeId);
        else this.routeImportSelectedIds.delete(routeId);
        const row = chk.closest("tr");
        if (row) this.updateRouteImportRowClass(row, chk.checked);
        this.updateRouteImportState();
      });
    });
  }

  updateRouteImportRowClass(row, isChecked) {
    if (isChecked) row.classList.add("selected");
    else row.classList.remove("selected");
  }

  syncRouteImportCheckboxes() {
    document.querySelectorAll(".route-import-checkbox").forEach(chk => {
      const id = chk.getAttribute("data-route-id");
      chk.checked = this.routeImportSelectedIds.has(id);
      const row = chk.closest("tr");
      if (row) this.updateRouteImportRowClass(row, chk.checked);
    });
  }

  updateRouteImportState() {
    const total = this.routeImportCandidates.length;
    const selected = this.routeImportSelectedIds.size;
    const visible = this.routeImportFiltered.length;

    // Counter
    const counterEl = document.getElementById("route-import-counter");
    if (counterEl) {
      if (visible < total) {
        counterEl.textContent = `${selected} of ${total} selected (${visible} in search)`;
      } else {
        counterEl.textContent = `${selected} of ${total} selected`;
      }
    }

    // Select All Checkbox state (with indeterminate support)
    const selectAllChk = document.getElementById("route-import-select-all");
    if (selectAllChk) {
      const visibleSelectedCount = this.routeImportFiltered.filter(r => this.routeImportSelectedIds.has(r.routeId)).length;
      if (visibleSelectedCount === 0) {
        selectAllChk.checked = false;
        selectAllChk.indeterminate = false;
      } else if (visibleSelectedCount === visible && visible > 0) {
        selectAllChk.checked = true;
        selectAllChk.indeterminate = false;
      } else {
        selectAllChk.checked = false;
        selectAllChk.indeterminate = true;
      }
    }

    // Check for Overwrites / Conflicts among selected
    const selectedOverwrites = [];
    const selectedConflicts = [];
    this.routeImportCandidates.forEach(r => {
      if (this.routeImportSelectedIds.has(r.routeId)) {
        if (r._importStatus === "CONFLICT") {
          selectedConflicts.push(r);
        } else if (r._importStatus === "EXISTS") {
          selectedOverwrites.push(r);
        }
      }
    });

    const conflictBanner = document.getElementById("route-import-conflict-banner");
    const conflictText = document.getElementById("route-import-conflict-text");
    const confirmOverwriteCheck = document.getElementById("route-import-confirm-overwrite");
    const submitBtn = document.getElementById("btn-route-import-submit");

    const hasDangerousOverwrites = selectedConflicts.length > 0 || selectedOverwrites.length > 0;

    if (hasDangerousOverwrites) {
      if (conflictBanner) conflictBanner.style.display = "block";
      if (conflictText) {
        const parts = [];
        if (selectedConflicts.length > 0) {
          parts.push(`<strong>${selectedConflicts.length} route(s)</strong> conflict with existing Firestore names (${selectedConflicts.slice(0, 3).map(r => r.routeId).join(", ")}${selectedConflicts.length > 3 ? "..." : ""}).`);
        }
        if (selectedOverwrites.length > 0) {
          parts.push(`<strong>${selectedOverwrites.length} route(s)</strong> already exist in Firestore and will be updated.`);
        }
        conflictText.innerHTML = parts.join(" ");
      }
    } else {
      if (conflictBanner) conflictBanner.style.display = "none";
    }

    // Submit button enablement
    if (submitBtn) {
      submitBtn.textContent = `Import Selected (${selected})`;
      if (selected === 0) {
        submitBtn.disabled = true;
      } else if (hasDangerousOverwrites && (!confirmOverwriteCheck || !confirmOverwriteCheck.checked)) {
        submitBtn.disabled = true;
      } else {
        submitBtn.disabled = false;
      }
    }
  }

  async executeRouteImport() {
    const selectedRoutes = this.routeImportCandidates.filter(r => this.routeImportSelectedIds.has(r.routeId));
    if (selectedRoutes.length === 0) return;

    const confirmOverwrite = document.getElementById("route-import-confirm-overwrite")?.checked === true;
    const progressBox = document.getElementById("route-import-progress-box");
    const progressText = document.getElementById("route-import-progress-text");
    const progressPercent = document.getElementById("route-import-progress-percent");
    const progressBar = document.getElementById("route-import-progress-bar");
    const summaryBox = document.getElementById("route-import-result-summary");
    const submitBtn = document.getElementById("btn-route-import-submit");

    if (progressBox) progressBox.style.display = "block";
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.textContent = "Writing...";
    }
    if (summaryBox) summaryBox.style.display = "none";

    try {
      const res = await routeService.importRoutes(selectedRoutes, {
        allowOverwrite: confirmOverwrite,
        onProgress: ({ current, total }) => {
          const pct = Math.round((current / total) * 100);
          if (progressPercent) progressPercent.textContent = `${pct}%`;
          if (progressBar) progressBar.style.width = `${pct}%`;
          if (progressText) progressText.textContent = `Writing routes to Firestore (${current} of ${total})...`;
        }
      });

      // Audit Log
      await auditService.logAction(
        this.routeImportType === "default" ? "DEFAULT_ROUTES_SEEDED" : "MORNING_ROUTES_IMPORTED",
        "ROUTES",
        "BATCH",
        {
          totalSelected: selectedRoutes.length,
          created: res.created,
          updated: res.updated,
          skipped: res.skipped,
          failedCount: res.failed.length
        },
        authService.userProfile
      );

      // Render Result Summary
      if (progressBox) progressBox.style.display = "none";
      if (summaryBox) {
        summaryBox.style.display = "block";
        const hasFailures = res.failed.length > 0;
        summaryBox.style.background = hasFailures ? "#FEF2F2" : "#F0FDF4";
        summaryBox.style.border = `1px solid ${hasFailures ? '#FECACA' : '#BBF7D0'}`;
        summaryBox.style.color = hasFailures ? "#991B1B" : "#166534";

        let summaryHtml = `
          <div style="font-weight:700;font-size:13px;margin-bottom:4px;">
            ${hasFailures ? '⚠️ Import Finished with Warnings' : '✅ Import Completed Successfully!'}
          </div>
          <div style="font-size:12px;">
            <strong>${res.created}</strong> created &bull;
            <strong>${res.updated}</strong> updated &bull;
            <strong>${res.skipped}</strong> skipped (not overwritten) &bull;
            <strong>${res.failed.length}</strong> failed
          </div>
        `;

        if (hasFailures) {
          summaryHtml += `
            <div style="margin-top:8px;font-size:11.5px;max-height:100px;overflow-y:auto;">
              ${res.failed.map(f => `<div>• <strong>${f.routeId}</strong>: ${f.reason}</div>`).join("")}
            </div>
          `;
        }

        summaryBox.innerHTML = summaryHtml;
      }

      this.toast(`Imported ${res.created + res.updated} routes to Cloud Firestore!`, "success");

      // Refresh routes table without page reload
      this.renderRoutes();

      if (submitBtn) {
        submitBtn.textContent = "✓ Finished";
        submitBtn.disabled = false;
        submitBtn.onclick = () => this.closeAllModals();
      }

      // Re-read existing map to update badges in the open modal if left open
      this.routeImportExistingMap = await routeService.getExistingRoutesMap();
    } catch (importErr) {
      console.error("[RouteImport] Unexpected error during import:", importErr);
      if (progressBox) progressBox.style.display = "none";
      if (summaryBox) {
        summaryBox.style.display = "block";
        summaryBox.style.background = "#FEF2F2";
        summaryBox.style.border = "1px solid #FECACA";
        summaryBox.style.color = "#DC2626";
        summaryBox.innerHTML = `<strong>Import Failed:</strong> ${importErr.message || "An unexpected error occurred."}`;
      }
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = "Retry Import";
      }
    }
  }
}

export const uiController = new UIController();
window.uiController = uiController;
