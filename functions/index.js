const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

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
