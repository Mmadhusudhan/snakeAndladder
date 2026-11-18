// Firebase Admin initialisation. Exposes `getFirebase()` which is lazy so
// tests can run the app with fakes and never touch the real SDK.
import admin from 'firebase-admin';

let app;

export function getFirebase() {
  if (app) return app;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const json = process.env.FIREBASE_SERVICE_ACCOUNT;
  const databaseURL = process.env.FIREBASE_DATABASE_URL || (projectId ? `https://${projectId}-default-rtdb.firebaseio.com` : undefined);
  if (json) {
    const serviceAccount = JSON.parse(json);
    app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId || serviceAccount.project_id,
      databaseURL,
    });
  } else {
    // GOOGLE_APPLICATION_CREDENTIALS or platform default credentials.
    app = admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId, databaseURL });
  }
  return app;
}

export function realDeps() {
  const fb = getFirebase();
  const db = admin.firestore(fb);
  const auth = admin.auth(fb);
  const rtdb = admin.database(fb);
  return {
    db,
    rtdb,
    verifyIdToken: (token) => auth.verifyIdToken(token),
    FieldValue: admin.firestore.FieldValue,
  };
}
