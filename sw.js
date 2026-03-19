// ═══════════════════════════════════════════════════
// DermaCam Service Worker — Background Notifications
// Place this file at your project ROOT (same folder as app.py)
// ═══════════════════════════════════════════════════

const CACHE_NAME = 'dermacam-v1';

// Install
self.addEventListener('install', e => {
  self.skipWaiting();
});

// Activate
self.addEventListener('activate', e => {
  e.waitUntil(clients.claim());
});

// ── Push notification handler ──────────────────────
self.addEventListener('push', e => {
  const data = e.data ? e.data.json() : {};
  e.waitUntil(
    self.registration.showNotification(data.title || 'DermaCam 🔬', {
      body: data.body || 'Time for your skincare routine!',
      icon: data.icon || '/static/icon.png',
      badge: '/static/icon.png',
      tag: data.tag || 'dermacam-reminder',
      vibrate: [200, 100, 200],
      actions: [
        { action: 'open', title: '✅ Done' },
        { action: 'snooze', title: '⏰ 10 min later' }
      ],
      data: { url: '/', reminderId: data.reminderId }
    })
  );
});

// ── Notification click handler ──────────────────────
self.addEventListener('notificationclick', e => {
  e.notification.close();

  if (e.action === 'snooze') {
    // Snooze: re-notify after 10 minutes
    const reminderId = e.notification.data?.reminderId;
    setTimeout(() => {
      self.registration.showNotification('DermaCam — Snooze Over! ⏰', {
        body: e.notification.body,
        icon: '/static/icon.png',
        tag: 'dermacam-snooze'
      });
    }, 10 * 60 * 1000);
    return;
  }

  // Open app on click
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      for (const client of clientList) {
        if (client.url.includes('/') && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});

// ── Background sync for scheduled reminders ─────────
// Stores reminders in IndexedDB, fires them at correct time
// even when the tab is closed

const DB_NAME = 'dermacam-reminders';
const STORE   = 'reminders';

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = e => {
      e.target.result.createObjectStore(STORE, { keyPath: 'id' });
    };
    req.onsuccess = e => resolve(e.target.result);
    req.onerror   = e => reject(e.target.error);
  });
}

async function getAllReminders() {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx  = db.transaction(STORE, 'readonly');
    const req = tx.objectStore(STORE).getAll();
    req.onsuccess = e => resolve(e.target.result);
    req.onerror   = e => reject(e.target.error);
  });
}

// Check reminders every minute via periodic sync (if supported)
// Fallback: message from main thread
self.addEventListener('message', async e => {
  if (e.data?.type === 'SAVE_REMINDER') {
    const db = await openDB();
    const tx = db.transaction(STORE, 'readwrite');
    tx.objectStore(STORE).put(e.data.reminder);
  }

  if (e.data?.type === 'DELETE_REMINDER') {
    const db = await openDB();
    const tx = db.transaction(STORE, 'readwrite');
    tx.objectStore(STORE).delete(e.data.id);
  }

  if (e.data?.type === 'CHECK_REMINDERS') {
    const reminders = await getAllReminders();
    const now = new Date();
    const hh  = now.getHours().toString().padStart(2,'0');
    const mm  = now.getMinutes().toString().padStart(2,'0');
    const currentTime = `${hh}:${mm}`;
    const today = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][now.getDay()];

    for (const r of reminders) {
      if (r.time !== currentTime) continue;

      // Frequency check
      if (r.freq === 'Weekdays only' && ['Saturday','Sunday'].includes(today)) continue;
      if (r.freq === 'Weekly' && today !== r.startDay) continue;

      // Don't fire twice in same minute
      const lastFired = r.lastFired || '';
      const todayStr  = now.toDateString();
      if (lastFired === `${todayStr}-${currentTime}`) continue;

      // Fire notification
      await self.registration.showNotification(`DermaCam 🔬 — ${r.type}`, {
        body: `Time for your ${r.type}! Keep your skin glowing ✨`,
        icon: '/static/icon.png',
        tag: `reminder-${r.id}`,
        vibrate: [200, 100, 200],
        actions: [
          { action: 'open',   title: '✅ Done' },
          { action: 'snooze', title: '⏰ Snooze 10min' }
        ],
        data: { reminderId: r.id, body: `Time for your ${r.type}!` }
      });

      // Update lastFired in DB
      const db = await openDB();
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put({ ...r, lastFired: `${todayStr}-${currentTime}` });
    }
  }
});