/**
 * Interactive Fleet Map & Route Visualizer Controller
 * Uses Leaflet.js with CartoDB Voyager tiles for clear, responsive mapping
 */

export class MapController {
  constructor(containerId, options = {}) {
    this.containerId = containerId;
    this.options = options;
    this.map = null;
    this.busMarkers = {};
    this.routeLayers = [];
    this.stopMarkers = [];
    this.onBusSelect = options.onBusSelect || null;
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
   * Create custom styled HTML marker icon for bus
   */
  createBusIcon(bus, isSelected = false) {
    let color = "#059669"; // Green LIVE
    let pulse = true;
    if (bus.status === "STALE") {
      color = "#D97706"; // Amber
      pulse = false;
    } else if (bus.status === "OFFLINE") {
      color = "#64748B"; // Gray
      pulse = false;
    }

    const ringStyle = isSelected ? "box-shadow: 0 0 0 4px #0265D2, 0 8px 20px rgba(2,101,210,0.4);" : "box-shadow: 0 4px 12px rgba(0,0,0,0.18);";
    const pulseHtml = pulse ? `<span style="position:absolute;inset:-4px;border-radius:50%;background:${color};opacity:0.4;animation:ping 1.5s cubic-bezier(0,0,0.2,1) infinite;"></span>` : "";

    const html = `
      <div style="position:relative;width:38px;height:38px;display:flex;align-items:center;justify-content:center;cursor:pointer;">
        ${pulseHtml}
        <div style="width:34px;height:34px;border-radius:50%;background:${color};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px;border:2.5px solid #ffffff;${ringStyle}transition:transform 0.2s;">
          🚌
        </div>
      </div>
    `;

    return L.divIcon({
      className: 'custom-bus-marker',
      html: html,
      iconSize: [38, 38],
      iconAnchor: [19, 19]
    });
  }

  /**
   * Update all bus markers on the map smoothly
   */
  updateBuses(buses, selectedBusId = null) {
    if (!this.map) return;

    const activeIds = new Set();

    buses.forEach((bus) => {
      const id = bus.id;
      activeIds.add(id);
      const isSel = id === selectedBusId;
      const lat = bus.latitude;
      const lng = bus.longitude;

      if (this.busMarkers[id]) {
        // Move existing marker smoothly
        const marker = this.busMarkers[id];
        marker.setLatLng([lat, lng]);
        marker.setIcon(this.createBusIcon(bus, isSel));
      } else {
        // Create new marker
        const marker = L.marker([lat, lng], {
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
        this.map.removeLayer(this.busMarkers[id]);
        delete this.busMarkers[id];
      }
    });
  }

  /**
   * Render route polyline and stops
   */
  renderRoutePath(route) {
    if (!this.map) return;
    this.clearRoutePaths();

    if (!route || !route.stopCoordinates || route.stopCoordinates.length === 0) return;

    const latlngs = route.stopCoordinates.map((c) => [c.lat, c.lng]);

    // Route Polyline
    const polyline = L.polyline(latlngs, {
      color: "#0265D2",
      weight: 5,
      opacity: 0.85,
      dashArray: null
    }).addTo(this.map);
    this.routeLayers.push(polyline);

    // Stop markers
    route.stops.forEach((stopName, idx) => {
      const coord = route.stopCoordinates[idx];
      if (!coord) return;

      const isFirst = idx === 0;
      const isLast = idx === route.stops.length - 1;
      const bg = isLast ? "#059669" : (isFirst ? "#0265D2" : "#475569");

      const icon = L.divIcon({
        className: 'stop-pin',
        html: `<div style="width:22px;height:22px;border-radius:50%;background:${bg};color:#fff;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,0.2);">${idx + 1}</div>`,
        iconSize: [22, 22],
        iconAnchor: [11, 11]
      });

      const marker = L.marker([coord.lat, coord.lng], { icon: icon })
        .bindPopup(`<strong>Stop ${idx + 1}:</strong> ${stopName}`)
        .addTo(this.map);

      this.stopMarkers.push(marker);
    });

    try {
      this.map.fitBounds(polyline.getBounds(), { padding: [40, 40] });
    } catch (e) {}
  }

  clearRoutePaths() {
    this.routeLayers.forEach((l) => this.map.removeLayer(l));
    this.stopMarkers.forEach((m) => this.map.removeLayer(m));
    this.routeLayers = [];
    this.stopMarkers = [];
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
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }
}
