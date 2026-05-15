const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

exports.deleteOwnAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");

  const db = admin.firestore();

  const deleteSubcollection = async (collRef) => {
    const snap = await collRef.get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  };

  const userRef = db.collection("users").doc(uid);
  await deleteSubcollection(userRef.collection("scans"));
  await deleteSubcollection(userRef.collection("settings"));
  await userRef.delete();

  // Delete safe_scans/{uid} and its scans subcollection
  try {
    const safeRef = db.collection("safe_scans").doc(uid);
    await deleteSubcollection(safeRef.collection("scans"));
    await safeRef.delete();
  } catch (e) {
    // non-fatal
  }

  // Delete false reports linked to this user
  try {
    const reports = await db.collection("false_reports")
        .where("userId", "==", uid).get();
    if (!reports.empty) {
      const b = db.batch();
      reports.docs.forEach((doc) => b.delete(doc.ref));
      await b.commit();
    }
  } catch (e) {
    // non-fatal
  }

  // Delete the Firebase Auth account last
  await admin.auth().deleteUser(uid);
  return {success: true};
});

exports.deleteAuthUser = onCall(async (request) => {
  // Only allow admins to call this function
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const callerDoc = await admin.firestore()
      .collection("users").doc(callerUid).get();
  if (!callerDoc.exists || callerDoc.data().role !== "Admin") {
    throw new HttpsError("permission-denied", "Must be an admin.");
  }

  const {uid} = request.data;
  if (!uid) {
    throw new HttpsError("invalid-argument", "Missing uid.");
  }

  await admin.auth().deleteUser(uid);
  return {success: true};
});
