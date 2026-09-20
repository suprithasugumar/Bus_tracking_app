/**
 * Interactive Fleet Map & Route Visualizer Controller
 * Uses Leaflet.js with smooth marker interpolation, heading rotation, and automated stop detection visualizer
 */

export class MapController {
  constructor(containerId, options = {}) {
    this.containerId = containerId;
    this.options = options;
    this.map = null;
    this.busMarkers = {};
    this.markerAnimations = {};
    this.routeLayers = [];
    this.stopMarkers = [];
    this.onBusSelect = options.onBusSelect || null;
    this.currentRoute = null;
    this.showRouteLine = true;
  }

  /**
   * Initialize Leaflet map instance
   */
  init(defaultCenter = [13.0400, 80.2200], defaultZoom = 12) {
    const el = document.getElementById(this.containerId);
    if (!el || this.map) return;

    this.map = L.map(this.containerId, {
      zoomControl: true,
      attributionControl: false
    }).setView(defaultCenter, defaultZoom);

    // Standard OpenStreetMap tile layer (No API Key or Billing Required)
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors'
    }).addTo(this.map);

    setTimeout(() => {
      if (this.map) this.map.invalidateSize();
    }, 200);
  }

  /**
   * Invalidate size for container resizing
   */
  invalidateSize() {
    if (this.map) {
      setTimeout(() => this.map.invalidateSize(), 100);
    }
  }

  /**
   * Create custom styled HTML marker icon for bus with smooth rotation
   */
  createBusIcon(bus, isSelected = false) {
    let pinColor = "#0D47A1"; // Royal Blue for LIVE
    if (bus.status === "STALE") {
      pinColor = "#D97706"; // Amber
    } else if (bus.status === "OFFLINE") {
      pinColor = "#475569"; // Slate Gray
    }

    const ringEffect = isSelected ? "filter: drop-shadow(0 0 8px rgba(13,71,161,0.9));" : "filter: drop-shadow(0 3px 6px rgba(0,0,0,0.3));";

    const svgHtml = `
      <div style="position:relative;width:32px;height:44px;cursor:pointer;${ringEffect}">
        <svg width="32" height="44" viewBox="0 0 32 44" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M16 43C16 43 30 25.5 30 15.5C30 7.49187 23.732 1 16 1C8.26801 1 2 7.49187 2 15.5C2 25.5 16 43 16 43Z" fill="${pinColor}" stroke="#ffffff" stroke-width="1.8"/>
          <circle cx="16" cy="15.5" r="9.5" fill="#ffffff"/>
        </svg>
        <div style="position:absolute;top:6px;left:0;width:32px;text-align:center;font-size:11px;line-height:18px;">
          🚌
        </div>
      </div>
    `;

    return L.divIcon({
      className: 'custom-bus-marker',
      html: svgHtml,
      iconSize: [32, 44],
      iconAnchor: [16, 43]
    });
  }

  /**
   * Smoothly interpolate marker from start to target position using requestAnimationFrame
   */
  animateMarker(id, marker, startLatLng, targetLatLng, durationMs = 950) {
    if (!startLatLng || (startLatLng.lat === targetLatLng.lat && startLatLng.lng === targetLatLng.lng)) {
      marker.setLatLng(targetLatLng);
      return;
    }

    if (this.markerAnimations[id]) {
      cancelAnimationFrame(this.markerAnimations[id]);
    }

    const startTime = performance.now();

    const step = (currentTime) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / durationMs, 1.0);

      // Ease-in-out cubic formula
      const ease = progress < 0.5
        ? 4 * progress * progress * progress
        : 1 - Math.pow(-2 * progress + 2, 3) / 2;

      const currentLat = startLatLng.lat + (targetLatLng.lat - startLatLng.lat) * ease;
      const currentLng = startLatLng.lng + (targetLatLng.lng - startLatLng.lng) * ease;

      marker.setLatLng([currentLat, currentLng]);

      if (progress < 1.0) {
        this.markerAnimations[id] = requestAnimationFrame(step);
      } else {
        delete this.markerAnimations[id];
      }
    };

    this.markerAnimations[id] = requestAnimationFrame(step);
  }

  /**
   * Update all bus markers on the map smoothly without teleporting/jumping
   */
  updateBuses(buses, selectedBusId = null) {
    if (!this.map) return;

    const activeIds = new Set();

    buses.forEach((bus) => {
      const id = bus.id;
      activeIds.add(id);
      const isSel = id === selectedBusId;
      const targetLatLng = L.latLng(bus.latitude, bus.longitude);

      if (this.busMarkers[id]) {
        const marker = this.busMarkers[id];
        const currentLatLng = marker.getLatLng();

        // Animate movement smoothly over time instead of teleporting
        this.animateMarker(id, marker, currentLatLng, targetLatLng);
        marker.setIcon(this.createBusIcon(bus, isSel));
      } else {
        // Create new marker
        const marker = L.marker(targetLatLng, {
          icon: this.createBusIcon(bus, isSel),
          title: bus.routeName || bus.id
        }).addTo(this.map);

        marker.on('click', () => {
          if (this.onBusSelect) this.onBusSelect(bus);
        });

        this.busMarkers[id] = marker;
      }
    });

    // Remove markers that are no longer in telemetry
    Object.keys(this.busMarkers).forEach((id) => {
      if (!activeIds.has(id)) {
        if (this.markerAnimations[id]) {
          cancelAnimationFrame(this.markerAnimations[id]);
          delete this.markerAnimations[id];
        }
        this.map.removeLayer(this.busMarkers[id]);
        delete this.busMarkers[id];
      }
    });
  }

  /**
   * Render route polyline and stops with automated completion indicators
   */
  renderRoutePath(route, activeBus = null) {
    if (!this.map) return;
    this.clearRoutePaths();
    this.currentRoute = route;

    if (!route || !route.stopCoordinates || route.stopCoordinates.length === 0) return;

    const polyPoints = (route.polylinePoints && route.polylinePoints.length > 0)
      ? route.polylinePoints
      : route.stopCoordinates;
    const latlngs = polyPoints.map((c) => [c.lat, c.lng]);

    // Road-following Route Polyline
    const polyline = L.polyline(latlngs, {
      color: "#0265D2",
      weight: 5,
      opacity: 0.85,
      lineCap: 'round',
      lineJoin: 'round',
      dashArray: null
    });
    if (this.showRouteLine) {
      polyline.addTo(this.map);
    }
    this.routeLayers.push(polyline);


    const completedStops = activeBus?.completedStops || [];
    const currentStopIdx = activeBus?.currentStopIndex || 0;

    // Stop markers with automated completion indicators
    route.stops.forEach((stopName, idx) => {
      const coord = route.stopCoordinates[idx];
      if (!coord) return;

      const isCompleted = completedStops.includes(stopName) || (idx < currentStopIdx && completedStops.length > 0);
      const isCurrentTarget = idx === currentStopIdx && !isCompleted && activeBus?.status === "LIVE";

      let bg = "#0D47A1"; // Deep Transit Blue
      let label = `${idx + 1}`;
      let statusBadge = `<span style="color:#64748B;">Upcoming Stop</span>`;

      if (isCompleted) {
        bg = "#059669"; // Green
        label = "✓";
        statusBadge = `<span style="color:#059669;font-weight:700;">✅ Stop Reached (Completed)</span>`;
      } else if (isCurrentTarget) {
        bg = "#0284C7"; // Vibrant Cyan next stop
        label = "➔";
        statusBadge = `<span style="color:#0284C7;font-weight:700;">➔ Next Target Stop</span>`;
      } else if (idx === route.stops.length - 1) {
        bg = "#DC2626"; // Destination red
      }

      const pulseRing = isCurrentTarget ? `<span style="position:absolute;inset:-3px;border-radius:50%;background:#0284C7;opacity:0.4;animation:ping 1.5s cubic-bezier(0,0,0.2,1) infinite;"></span>` : "";

      const icon = L.divIcon({
        className: 'stop-pin',
        html: `
          <div style="position:relative;width:24px;height:24px;display:flex;align-items:center;justify-content:center;">
            ${pulseRing}
            <div style="width:24px;height:24px;border-radius:50%;background:${bg};color:#fff;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,0.25);">
              ${label}
            </div>
          </div>
        `,
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      });

      const marker = L.marker([coord.lat, coord.lng], { icon: icon })
        .bindPopup(`
          <div style="font-family:sans-serif;font-size:12px;padding:2px;">
            <strong style="font-size:13px;display:block;margin-bottom:4px;">Stop ${idx + 1}: ${stopName}</strong>
            <div>${statusBadge}</div>
            <div style="color:#64748B;font-size:11px;margin-top:4px;">${coord.lat.toFixed(4)}, ${coord.lng.toFixed(4)}</div>
          </div>
        `)
        .addTo(this.map);

      this.stopMarkers.push(marker);
    });

    try {
      this.map.fitBounds(polyline.getBounds(), { padding: [40, 40] });
    } catch (e) {}
  }

  /**
   * Toggle showing/hiding route line on the map
   */
  toggleRouteLine(show = null) {
    this.showRouteLine = show !== null ? show : !this.showRouteLine;
    this.routeLayers.forEach((l) => {
      if (!this.showRouteLine) {
        if (this.map && this.map.hasLayer(l)) this.map.removeLayer(l);
      } else {
        if (this.map && !this.map.hasLayer(l)) l.addTo(this.map);
      }
    });
    return this.showRouteLine;
  }

  clearRoutePaths() {
    this.routeLayers.forEach((l) => this.map.removeLayer(l));
    this.stopMarkers.forEach((m) => this.map.removeLayer(m));
    this.routeLayers = [];
    this.stopMarkers = [];
    this.currentRoute = null;
  }

  /**
   * Fit map viewport to include all active buses
   */
  fitAllBuses(buses) {
    if (!this.map || !buses || buses.length === 0) return;
    const points = buses.map((b) => [b.latitude, b.longitude]);
    try {
      const bounds = L.latLngBounds(points);
      this.map.fitBounds(bounds, { padding: [50, 50], maxZoom: 15 });
    } catch (e) {}
  }

  /**
   * Center map on specific bus
   */
  focusBus(bus) {
    if (!this.map || !bus) return;
    this.map.setView([bus.latitude, bus.longitude], 15, { animate: true });
  }

  destroy() {
    Object.keys(this.markerAnimations).forEach((id) => {
      cancelAnimationFrame(this.markerAnimations[id]);
    });
    this.markerAnimations = {};

    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }
}
