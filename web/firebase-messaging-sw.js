importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDhEjcgx2JlqB5Wt5jAW07BlSD3SVx3Ad4',
  authDomain: "maintenance-b7282.firebaseapp.com",
  projectId: "maintenance-b7282",
  storageBucket: "maintenance-b7282.appspot.com",
  messagingSenderId: "840926699694",
  appId: "1:840926699694:web:1e1d88be3d81cc8a314d3f"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message: ', payload);

  const notificationTitle = payload.notification?.title || 'إشعار جديد';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/images/1.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});