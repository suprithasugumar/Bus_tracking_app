/**
 * Route & Schedule Management Service
 * Manages Cloud Firestore collection: /routes
 */

import { 
  db, 
  collection, 
  doc, 
  getDocs, 
  getDoc,
  setDoc, 
  updateDoc, 
  deleteDoc, 
  onSnapshot,
  writeBatch
} from "./firebase-config.js";

// Canonical seed dataset matching Flutter seed_service.dart
export const DEFAULT_CHENNAI_ROUTES = [
  {
    routeId: "route_01",
    routeName: "Route 1 – Anna Nagar",
    stops: [
      "Anna Nagar Tower",
      "Koyambedu Bus Stand",
      "Vadapalani",
      "Ashok Nagar",
      "Ekkattuthangal",
      "Guindy",
      "College"
    ],
    stopCoordinates: [
      { lat: 13.0850, lng: 80.2101 },
      { lat: 13.0694, lng: 80.1948 },
      { lat: 13.0524, lng: 80.2120 },
      { lat: 13.0358, lng: 80.2172 },
      { lat: 13.0069, lng: 80.2206 },
      { lat: 12.9916, lng: 80.2209 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:15 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_02",
    routeName: "Route 2 – T Nagar",
    stops: [
      "T Nagar Bus Terminus",
      "Saidapet",
      "Guindy",
      "St. Thomas Mount",
      "Chromepet",
      "Pallavaram",
      "College"
    ],
    stopCoordinates: [
      { lat: 13.0418, lng: 80.2341 },
      { lat: 13.0213, lng: 80.2231 },
      { lat: 13.0069, lng: 80.2206 },
      { lat: 12.9942, lng: 80.1970 },
      { lat: 12.9516, lng: 80.1462 },
      { lat: 12.9675, lng: 80.1491 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:20 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_03",
    routeName: "Route 3 – Tambaram",
    stops: [
      "Tambaram Sanatorium",
      "Chromepet",
      "Pallavaram",
      "St. Thomas Mount",
      "Guindy",
      "Saidapet",
      "College"
    ],
    stopCoordinates: [
      { lat: 12.9366, lng: 80.1264 },
      { lat: 12.9516, lng: 80.1462 },
      { lat: 12.9675, lng: 80.1491 },
      { lat: 12.9942, lng: 80.1970 },
      { lat: 13.0069, lng: 80.2206 },
      { lat: 13.0213, lng: 80.2231 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:30 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_04",
    routeName: "Route 4 – Velachery",
    stops: [
      "Velachery Checkpost",
      "Taramani",
      "Perungudi",
      "Sholinganallur",
      "Pallikaranai",
      "Medavakkam",
      "College"
    ],
    stopCoordinates: [
      { lat: 12.9815, lng: 80.2180 },
      { lat: 12.9784, lng: 80.2412 },
      { lat: 12.9654, lng: 80.2461 },
      { lat: 12.9010, lng: 80.2279 },
      { lat: 12.9348, lng: 80.2085 },
      { lat: 12.9194, lng: 80.1934 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:25 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_05",
    routeName: "Route 5 – Porur",
    stops: [
      "Porur Junction",
      "Valasaravakkam",
      "Virugambakkam",
      "Kodambakkam",
      "Vadapalani",
      "Koyambedu",
      "College"
    ],
    stopCoordinates: [
      { lat: 13.0382, lng: 80.1565 },
      { lat: 13.0450, lng: 80.1780 },
      { lat: 13.0500, lng: 80.1920 },
      { lat: 13.0520, lng: 80.2250 },
      { lat: 13.0524, lng: 80.2120 },
      { lat: 13.0694, lng: 80.1948 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:15 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_06",
    routeName: "Route 6 – Perambur",
    stops: [
      "Perambur Railway Station",
      "Villivakkam",
      "Kolathur",
      "Mogappair",
      "Anna Nagar East",
      "Koyambedu",
      "College"
    ],
    stopCoordinates: [
      { lat: 13.1110, lng: 80.2430 },
      { lat: 13.1090, lng: 80.2070 },
      { lat: 13.1240, lng: 80.2180 },
      { lat: 13.0840, lng: 80.1760 },
      { lat: 13.0850, lng: 80.2200 },
      { lat: 13.0694, lng: 80.1948 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:00 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_07",
    routeName: "Route 7 – Adyar",
    stops: [
      "Adyar Depot",
      "Thiruvanmiyur",
      "Besant Nagar",
      "Kotturpuram",
      "Saidapet",
      "Guindy",
      "College"
    ],
    stopCoordinates: [
      { lat: 13.0012, lng: 80.2565 },
      { lat: 12.9830, lng: 80.2594 },
      { lat: 13.0002, lng: 80.2667 },
      { lat: 13.0180, lng: 80.2410 },
      { lat: 13.0213, lng: 80.2231 },
      { lat: 13.0069, lng: 80.2206 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:20 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_08",
    routeName: "Route 8 – Avadi",
    stops: [
      "Avadi Bus Stand",
      "Ambattur OT",
      "Padi",
      "Mogappair West",
      "Koyambedu",
      "Vadapalani",
      "College"
    ],
    stopCoordinates: [
      { lat: 13.1180, lng: 80.1010 },
      { lat: 13.1140, lng: 80.1540 },
      { lat: 13.0970, lng: 80.1870 },
      { lat: 13.0780, lng: 80.1700 },
      { lat: 13.0694, lng: 80.1948 },
      { lat: 13.0524, lng: 80.2120 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:00 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_09",
    routeName: "Route 9 – OMR / IT Corridor",
    stops: [
      "Siruseri SIPCOT",
      "Perungudi",
      "Sholinganallur",
      "Karapakkam",
      "Taramani",
      "Thiruvanmiyur",
      "College"
    ],
    stopCoordinates: [
      { lat: 12.8250, lng: 80.2200 },
      { lat: 12.9654, lng: 80.2461 },
      { lat: 12.9010, lng: 80.2279 },
      { lat: 12.9150, lng: 80.2310 },
      { lat: 12.9784, lng: 80.2412 },
      { lat: 12.9830, lng: 80.2594 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:15 AM", evening: "5:15 PM" },
    isActive: true
  },
  {
    routeId: "route_10",
    routeName: "Route 10 – Poonamallee",
    stops: [
      "Poonamallee Terminus",
      "Maduravoyal",
      "Alapakkam",
      "Porur",
      "Valasaravakkam",
      "Koyambedu",
      "College"
    ],
    stopCoordinates: [
      { lat: 13.0480, lng: 80.1110 },
      { lat: 13.0650, lng: 80.1600 },
      { lat: 13.0490, lng: 80.1700 },
      { lat: 13.0382, lng: 80.1565 },
      { lat: 13.0450, lng: 80.1780 },
      { lat: 13.0694, lng: 80.1948 },
      { lat: 12.9716, lng: 80.2200 }
    ],
    assignedDriverId: "",
    schedule: { morning: "7:10 AM", evening: "5:15 PM" },
    isActive: true
  }
];

class RouteService {
  constructor() {
    this.routes = [];
    this.listeners = [];
    this.unsubscribe = null;
  }

  /**
   * Listen to real-time updates from /routes
   */
  startListening(callback) {
    if (callback) this.listeners.push(callback);
    if (this.unsubscribe) return;

    const routesCol = collection(db, "routes");
    this.unsubscribe = onSnapshot(routesCol, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        const data = d.data();
        list.push({
          id: d.id,
          routeId: d.id,
          routeName: data.routeName || `Route ${d.id}`,
          stops: Array.isArray(data.stops) ? data.stops : [],
          stopCoordinates: Array.isArray(data.stopCoordinates) ? data.stopCoordinates : [],
          assignedDriverId: data.assignedDriverId || "",
          assignedDriverName: data.assignedDriverName || "",
          schedule: data.schedule || { morning: "7:30 AM", evening: "5:00 PM" },
          isActive: data.isActive !== false
        });
      });

      // Sort alphabetically by routeName / routeId
      list.sort((a, b) => a.routeId.localeCompare(b.routeId));
      this.routes = list;
      this.notifyListeners();
    }, (err) => {
      console.error("[RouteService] Firestore listen error:", err);
    });
  }

  stopListening() {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  notifyListeners() {
    this.listeners.forEach((cb) => {
      try {
        cb(this.routes);
      } catch (e) {
        console.error("[RouteService] Listener error:", e);
      }
    });
  }

  subscribe(callback) {
    this.listeners.push(callback);
    callback(this.routes);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== callback);
    };
  }

  /**
   * Save or Update a route
   */
  async saveRoute(route) {
    const routeId = route.routeId || `route_${String(this.routes.length + 1).padStart(2, "0")}`;
    const routeRef = doc(db, "routes", routeId);
    
    const payload = {
      routeName: route.routeName,
      stops: route.stops || [],
      stopCoordinates: route.stopCoordinates || [],
      assignedDriverId: route.assignedDriverId || "",
      schedule: route.schedule || { morning: "7:30 AM", evening: "5:00 PM" },
      isActive: route.isActive !== false
    };

    await setDoc(routeRef, payload, { merge: true });
    return routeId;
  }

  /**
   * Assign driver to route
   */
  async assignDriver(routeId, driverId, driverName) {
    const routeRef = doc(db, "routes", routeId);
    await updateDoc(routeRef, {
      assignedDriverId: driverId,
      assignedDriverName: driverName || ""
    });
  }

  /**
   * Toggle route active status
   */
  async toggleActive(routeId, isActive) {
    const routeRef = doc(db, "routes", routeId);
    await updateDoc(routeRef, { isActive: isActive });
  }

  /**
   * Delete route (with confirmation safeguard)
   */
  async deleteRoute(routeId) {
    const routeRef = doc(db, "routes", routeId);
    await deleteDoc(routeRef);
  }

  /**
   * Seed default 10 Chennai routes if collection is empty
   */
  async seedRoutes() {
    const batch = writeBatch(db);
    DEFAULT_CHENNAI_ROUTES.forEach((r) => {
      const ref = doc(db, "routes", r.routeId);
      batch.set(ref, {
        routeName: r.routeName,
        stops: r.stops,
        stopCoordinates: r.stopCoordinates,
        assignedDriverId: r.assignedDriverId,
        schedule: r.schedule,
        isActive: r.isActive
      }, { merge: true });
    });
    await batch.commit();
  }
}

export const routeService = new RouteService();
