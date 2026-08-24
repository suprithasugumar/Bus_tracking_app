const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Triggered automatically when a new document is written to the 'notifications' collection in Firestore.
 * Sends a real-time FCM Push Notification to all students subscribed to topic: route_<routeId>
 * (Works when app is closed, in background, or in foreground).
 */
exports.sendRouteNotificationOnCreate = onDocumentCreated(
  "notifications/{docId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log("No data associated with event");
      return;
    }

    const data = snap.data();
    const routeId = data.routeId;
    const message = data.message;
    const type = data.type || "info";

    if (!routeId || !message) {
      console.log("Missing routeId or message in notification doc:", snap.id);
      return;
    }

    // Determine notification title based on alert type
    let title = "📢 Route Notification";
    if (type === "breakdown") {
      title = "🚨 Bus Breakdown Alert!";
    } else if (type === "delay") {
      title = "⚠️ Bus Delay Alert!";
    }

    const topic = `route_${routeId}`;

    // Payload formatted for high-priority background & closed-app delivery
    const payload = {
      topic: topic,
      notification: {
        title: title,
        body: message,
      },
      data: {
        routeId: String(routeId),
        type: String(type),
        notificationId: String(snap.id),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "bus_tracking_channel",
          sound: "default",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: message,
            },
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log(
        `[FCM SUCCESS] Sent alert '${type}' to topic '${topic}':`,
        response
      );
    } catch (error) {
      console.error(
        `[FCM ERROR] Failed to send alert to topic '${topic}':`,
        error
      );
    }
  }
);

/**
 * Triggered automatically when a new document is written to the 'sos_alerts' collection in Firestore.
 * Sends emergency FCM push notifications to all users on the route & all drivers.
 */
exports.sendSosAlertOnCreate = onDocumentCreated(
  "sos_alerts/{docId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const routeId = data.routeId;
    const message = data.message || "Emergency SOS alert reported!";
    const driverName = data.driverName || "Driver";

    const title = "🆘 EMERGENCY SOS ALERT";
    const body = `${driverName}: ${message}`;

    const topic = routeId ? `route_${routeId}` : "all_drivers";

    const payload = {
      topic: topic,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "sos",
        routeId: String(routeId || ""),
        notificationId: String(snap.id),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "bus_tracking_channel",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log(`[SOS FCM SUCCESS] Sent to topic '${topic}':`, response);
    } catch (error) {
      console.error(`[SOS FCM ERROR] Failed to send to topic '${topic}':`, error);
    }
  }
);
